require 'actions/space_delete'

module CloudController
  class OrganizationDelete
    def initialize(org_roles_deleter, space_deleter)
      @org_roles_deleter = org_roles_deleter
      @space_deleter = space_deleter
    end

    def delete(org_dataset)
      org_dataset.each do |org|
        errs = @space_deleter.delete(org.spaces_dataset)
        unless errs.empty?
          error_message = errs.map(&:message).join("\n\n")
          return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
        end

        errs = @org_roles_deleter.delete(org)
        unless errs.empty?
          error_message = errs.map(&:message).join("\n\n")
          return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
        end

        org.destroy
      end
    end

    def timeout_error(dataset)
      org_name = dataset.first.name
      CloudController::Errors::ApiError.new_from_details('OrganizationDeleteTimeout', org_name)
    end
  end
end
