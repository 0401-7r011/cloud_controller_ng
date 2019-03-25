module VCAP::CloudController
  module Diego
    class MainLRPActionBuilder
      include ::Diego::ActionBuilder
      include ::Credhub::ConfigHelpers

      class << self
        def build(process, lrp_builder, ssh_key)
          self.new(process, lrp_builder, ssh_key).build
        end
      end

      def initialize(process, lrp_builder, ssh_key)
        @process = process
        @lrp_builder = lrp_builder
        @ssh_key = ssh_key
      end

      def build
        environment_variables = generate_environment_variables

        actions = []
        actions << generate_app_action(
          lrp_builder.start_command,
          lrp_builder.action_user,
          environment_variables
        )
        actions << generate_sidecar_action(lrp_builder.action_user, environment_variables) if sidecar?
        actions << generate_ssh_action(lrp_builder.action_user, environment_variables) if allow_ssh?
        codependent(actions)
      end

      private

      attr_reader :process, :lrp_builder, :ssh_key

      def generate_environment_variables
        running_env_vars = Environment.new(process, EnvironmentVariableGroup.running.environment_json).as_json

        env_vars = (running_env_vars + platform_options).map do |i|
          ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value'])
        end
        lrp_builder.port_environment_variables + env_vars
      end

      def generate_app_action(start_command, user, environment_variables)
        launcher_args = ['app', start_command || '', process.execution_metadata]

        action(::Diego::Bbs::Models::RunAction.new(
                 user:            user,
                 path:            '/tmp/lifecycle/launcher',
                 args:            launcher_args,
                 env:             environment_variables,
                 log_source:      "APP/PROC/#{process.type.upcase}",
                 resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: process.file_descriptors),
          ))
      end

      def sidecar?
        process.app.sidecars.detect { |sidecar| sidecar.process_types.include?(process.type) }.present?
      end

      def allow_ssh?
        process.enable_ssh
      end

      def platform_options
        return [] unless credhub_url.present? && cred_interpolation_enabled?

        [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: credhub_url)]
      end

      def generate_sidecar_action(user, environment_variables)
        sidecar = process.app.sidecars.detect { |sidecar| sidecar.process_types.include?(process.type) }
        action(::Diego::Bbs::Models::RunAction.new(
                 user:            user,
                 path:            '/tmp/lifecycle/launcher',

                 args: ['app', sidecar.command],
                 env:             environment_variables,
                 resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: process.file_descriptors),
            # log_source:      SSHD_LOG_SOURCE,
          ))
      end

      def generate_ssh_action(user, environment_variables)
        action(::Diego::Bbs::Models::RunAction.new(
                 user:            user,
                 path:            '/tmp/lifecycle/diego-sshd',
                 args:            [
                   "-address=#{sprintf('0.0.0.0:%<port>d', port: DEFAULT_SSH_PORT)}",
                   "-hostKey=#{ssh_key.private_key}",
                   "-authorizedKey=#{ssh_key.authorized_key}",
                   '-inheritDaemonEnv',
                   '-logLevel=fatal',
                 ],
                 env:             environment_variables,
                 resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: process.file_descriptors),
                 log_source:      SSHD_LOG_SOURCE,
          ))
      end
    end
  end
end
