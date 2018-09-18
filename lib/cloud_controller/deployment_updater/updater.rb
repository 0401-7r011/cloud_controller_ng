require 'actions/process_restart'
require 'cloud_controller/deployment_updater/deployment_manipulator'

module VCAP::CloudController
  module DeploymentUpdater
    class Updater
      class << self
        def update
          logger = Steno.logger('cc.deployment_updater.update')
          logger.info('run-deployment-update')

          deployments_to_scale = DeploymentModel.where(state: DeploymentModel::DEPLOYING_STATE).all
          deployments_to_cancel = DeploymentModel.where(state: DeploymentModel::CANCELING_STATE).all

          begin
            workpool = WorkPool.new(50)

            logger.info("scaling #{deployments_to_scale.size} deployments")
            deployments_to_scale.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                DeploymentManipulator.new(d, l).scale
              end
            end

            logger.info("canceling #{deployments_to_cancel.size} deployments")

            deployments_to_cancel.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                DeploymentManipulator.new(d, l).cancel
              end
            end
          ensure
            workpool.drain
          end
        end

        private

        def scale_deployment(deployment, logger)
          deployment.db.transaction do
            deployment.lock!

            app = deployment.app
            oldest_web_process = app.oldest_webish_process
            deploying_web_process = deployment.deploying_web_process

            app.lock!
            oldest_web_process.lock!
            deploying_web_process.lock!

            return unless ready_to_scale?(deployment, logger)

            if deploying_web_process.instances < deployment.original_web_process_instance_count
              scale_down_oldest_web_process(oldest_web_process)
              deploying_web_process.update(instances: deploying_web_process.instances + 1)
            else
              promote_deploying_web_process(deploying_web_process, oldest_web_process)

              cleanup_interim_deployment_processes(deploying_web_process, app)

              restart_non_web_processes(app)
              deployment.update(state: DeploymentModel::DEPLOYED_STATE)
            end
          end
        end

        def scale_down(webish_process)
          if webish_process.instances > 1
            webish_process.update(instances: webish_process.instances - 1)
          else
            webish_process.destroy
            if webish_process.type != 'web'
              RouteMappingModel.where(app: webish_process.app, process_type: webish_process.type).map(&:destroy)
            end
          end
        end

        def cancel_deployment(deployment, logger)
          deployment.db.transaction do
            deployment.lock!

            app = deployment.app
            original_web_process = app.web_process
            deploying_web_process = deployment.deploying_web_process

            app.lock!
            original_web_process.lock!
            deploying_web_process.lock!

            original_web_process.update(instances: deployment.original_web_process_instance_count)

            RouteMappingModel.where(app: app, process_type: deploying_web_process.type).map(&:destroy)
            deploying_web_process.destroy
            deployment.update(state: DeploymentModel::CANCELED_STATE)
            logger.info("ran-cancel-deployment-for-#{deployment.guid}")
          end
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end

        def promote_deploying_web_process(deploying_web_process, oldest_web_process)
          RouteMappingModel.where(app: deploying_web_process.app,
                                  process_type: deploying_web_process.type).map(&:destroy)
          deploying_web_process.update(type: ProcessTypes::WEB)
          oldest_web_process.destroy
        end

        def cleanup_interim_deployment_processes(deploying_web_process, app)
          app.processes.select { |p| ProcessTypes.webish?(p.type) }.each do |webish_process|
            next if webish_process.guid == deploying_web_process.guid
            webish_process.destroy
            if webish_process.type != 'web'
              RouteMappingModel.where(app: webish_process.app, process_type: webish_process.type).map(&:destroy)
            end
          end
        end

        def restart_non_web_processes(app)
          app.processes.reject(&:web?).each do |process|
            VCAP::CloudController::ProcessRestart.restart(process: process, config: Config.config, stop_in_runtime: true)
          end
        end
      end
    end
  end
end
