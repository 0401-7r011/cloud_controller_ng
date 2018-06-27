module CloudController
  class SpaceCreate
    class Error < ::StandardError
    end

    def initialize(perm_client:)
      @perm_client = perm_client
    end

    def create(org, message)
      space = CloudController::Space.create(name: message.name, organization: org)
      CloudController::Roles::SPACE_ROLE_NAMES.each do |role|
        perm_client.create_space_role(role: role, space_id: space.guid)
      end
      space
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    private

    attr_reader :perm_client

    def validation_error!(error)
      if error.errors.on([:organization_id, :name])&.include?(:unique)
        error!('Name must be unique per organization')
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
