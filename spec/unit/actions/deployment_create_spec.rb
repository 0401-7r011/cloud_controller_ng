require 'spec_helper'
require 'actions/deployment_create'

module VCAP::CloudController
  RSpec.describe DeploymentCreate do
    let(:app) { VCAP::CloudController::AppModel.make(droplet: droplet) }
    let!(:web_process) { VCAP::CloudController::ProcessModel.make(app: app) }
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    let(:other_droplet) { VCAP::CloudController::DropletModel.make(app: app) }
    let!(:route1) { VCAP::CloudController::Route.make(space: app.space) }
    let!(:route_mapping1) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route1, process_type: web_process.type) }
    let!(:route2) { VCAP::CloudController::Route.make(space: app.space) }
    let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route2, process_type: web_process.type) }
    let(:user_audit_info) { instance_double(UserAuditInfo, user_guid: nil) }

    describe '#create' do
      context 'when a droplet is provided' do
        it 'creates a deployment with the provided droplet' do
          deployment = nil

          expect {
            deployment = DeploymentCreate.create(app: app, droplet: other_droplet, user_audit_info: user_audit_info)
          }.to change { DeploymentModel.count }.by(1)

          expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
          expect(deployment.app_guid).to eq(app.guid)
          expect(deployment.droplet_guid).to eq(other_droplet.guid)
        end
      end

      context 'when a droplet is not provided' do
        it 'creates a deployment with the droplet of the app' do
          deployment = nil

          expect {
            deployment = DeploymentCreate.create(app: app, droplet: nil, user_audit_info: user_audit_info)
          }.to change { DeploymentModel.count }.by(1)

          expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
          expect(deployment.app_guid).to eq(app.guid)
          expect(deployment.droplet_guid).to eq(droplet.guid)
        end
      end

      it 'creates a process of web-deployment-guid type with the same characteristics as the existing web process' do
        deployment = DeploymentCreate.create(app: app, droplet: nil, user_audit_info: user_audit_info)

        deploying_web_process = app.processes.select { |p| p.type == "web-deployment-#{deployment.guid}" }.first
        expect(deploying_web_process.state).to eq ProcessModel::STARTED
        expect(deploying_web_process.command).to eq(web_process.command)
        expect(deploying_web_process.memory).to eq(web_process.memory)
        expect(deploying_web_process.file_descriptors).to eq(web_process.file_descriptors)
        expect(deploying_web_process.disk_quota).to eq(web_process.disk_quota)
        expect(deploying_web_process.metadata).to eq(web_process.metadata)
        expect(deploying_web_process.detected_buildpack).to eq(web_process.detected_buildpack)
        expect(deploying_web_process.health_check_timeout).to eq(web_process.health_check_timeout)
        expect(deploying_web_process.health_check_type).to eq(web_process.health_check_type)
        expect(deploying_web_process.health_check_http_endpoint).to eq(web_process.health_check_http_endpoint)
        expect(deploying_web_process.health_check_invocation_timeout).to eq(web_process.health_check_invocation_timeout)
        expect(deploying_web_process.enable_ssh).to eq(web_process.enable_ssh)
        expect(deploying_web_process.ports).to eq(web_process.ports)
      end

      it 'saves the webish process on the deployment' do
        deployment = DeploymentCreate.create(app: app, droplet: nil, user_audit_info: user_audit_info)

        deploying_web_process = app.processes.select { |p| p.type == "web-deployment-#{deployment.guid}" }.first
        expect(deployment.deploying_web_process_guid).to eq(deploying_web_process.guid)
      end

      it 'creates route mappings for each route mapped to the existing web process' do
        deployment = DeploymentCreate.create(app: app, droplet: nil, user_audit_info: user_audit_info)
        deploying_web_process = app.processes.select { |p| p.type == "web-deployment-#{deployment.guid}" }.first

        expect(deploying_web_process.routes).to contain_exactly(route1, route2)
      end

      context 'when the app does not have a droplet set' do
        let(:app) { VCAP::CloudController::AppModel.make }

        it 'sets the droplet on the deployment to nil' do
          deployment = DeploymentCreate.create(app: app, droplet: nil, user_audit_info: user_audit_info)

          expect(deployment.app).to eq(app)
          expect(deployment.droplet).to be_nil
        end
      end
    end
  end
end
