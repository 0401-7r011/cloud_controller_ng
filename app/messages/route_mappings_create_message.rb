require 'messages/base_message'
require 'models/helpers/process_types'

module CloudController
  class RouteMappingsCreateMessage < BaseMessage
    register_allowed_keys [:relationships]

    validates_with NoAdditionalKeysValidator
    validates :app, hash: true
    validates :app_guid, guid: true
    validates :route, hash: true
    validates :route_guid, guid: true
    validates :process, hash: true, allow_nil: true
    validates :process_type, string: true, allow_nil: true

    def app
      HashUtils.dig(relationships, :app)
    end

    def app_guid
      HashUtils.dig(app, :guid)
    end

    def process
      HashUtils.dig(relationships, :process)
    end

    def process_type
      HashUtils.dig(process, :type) || ProcessTypes::WEB
    end

    def route
      HashUtils.dig(relationships, :route)
    end

    def route_guid
      HashUtils.dig(route, :guid)
    end
  end
end
