module VCAP::CloudController
  class RouteMappingDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def unmap(route_mapping)
      logger.debug("removing route mapping: #{route_mapping.inspect}")

      route_handler = ProcessRouteHandler.new(route_mapping.process)

      event_repository.record_unmap_route(
        route_mapping.app,
        route_mapping.route,
        @user_audit_info,
        route_mapping.guid,
        route_mapping.process_type
      )
      route_handler.update_route_information(perform_validation: false)
    end

    def delete(route_mappings)
      route_mappings = Array(route_mappings)

      route_mappings.each do |route_mapping|
        unmap(route_mapping)
        RouteMappingModel.db.transaction do
          next if RouteMappingModel.find(guid: route_mapping.guid).nil?
          route_mapping.destroy
        end
      end
    end

    private

    def event_repository
      Repositories::AppEventRepository.new
    end

    def logger
      @logger ||= Steno.logger('cc.action.delete_route_mapping')
    end
  end
end
