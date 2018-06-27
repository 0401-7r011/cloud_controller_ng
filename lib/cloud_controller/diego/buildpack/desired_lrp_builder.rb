module CloudController
  module Diego
    module Buildpack
      class DesiredLrpBuilder
        include ::Credhub::ConfigHelpers
        include ::Diego::ActionBuilder

        attr_reader :start_command

        def initialize(config, opts)
          @config = config
          @stack = opts[:stack]
          @droplet_uri = opts[:droplet_uri]
          @process_guid = opts[:process_guid]
          @droplet_hash = opts[:droplet_hash]
          @ports = opts[:ports]
          @checksum_algorithm = opts[:checksum_algorithm]
          @checksum_value = opts[:checksum_value]
          @start_command = opts[:start_command]
        end

        def cached_dependencies
          lifecycle_bundle_key = "buildpack/#{@stack}".to_sym
          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: LifecycleBundleUriGenerator.uri(@config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
              to: '/tmp/lifecycle',
              cache_key: "buildpack-#{@stack}-lifecycle"
            )
          ]
        end

        def root_fs
          if @config.get(:diego, :temporary_oci_buildpack_mode) == 'oci-phase-1'
            "preloaded+layer:#{@stack}?layer=#{UriUtils.uri_escape(@droplet_uri)}&layer_path=#{action_user_home}&layer_digest=#{@checksum_value}"
          else
            "preloaded:#{@stack}"
          end
        end

        def setup
          return nil if @config.get(:diego, :temporary_oci_buildpack_mode) == 'oci-phase-1'

          serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: @droplet_uri,
              to: '.',
              cache_key: "droplets-#{@process_guid}",
              user: action_user,
              checksum_algorithm: @checksum_algorithm,
              checksum_value: @checksum_value,
            )
          ])
        end

        def global_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: DEFAULT_LANG)]
        end

        def ports
          @ports || [DEFAULT_APP_PORT]
        end

        def port_environment_variables
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: ports.first.to_s),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_PORT', value: ports.first.to_s),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_HOST', value: '0.0.0.0'),
          ]
        end

        def platform_options
          arr = []
          if credhub_url.present? && cred_interpolation_enabled?
            arr << ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: credhub_url)
          end

          arr
        end

        def privileged?
          @config.get(:diego, :use_privileged_containers_for_running)
        end

        def action_user
          'vcap'
        end

        def action_user_home
          "/home/#{action_user}"
        end
      end
    end
  end
end
