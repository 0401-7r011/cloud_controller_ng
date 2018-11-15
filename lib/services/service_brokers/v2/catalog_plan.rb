module VCAP::Services::ServiceBrokers::V2
  class CatalogPlan
    include CatalogValidationHelper

    attr_reader :broker_provided_id, :name, :description, :metadata
    attr_reader :catalog_service, :errors, :free, :bindable, :schemas

    def initialize(catalog_service, attrs)
      @catalog_service    = catalog_service
      @broker_provided_id = attrs['id']
      @metadata           = attrs['metadata']
      @name               = attrs['name']
      @description        = attrs['description']
      @errors             = VCAP::Services::ValidationErrors.new
      @free               = attrs['free'].nil? ? true : attrs['free']
      @bindable           = attrs['bindable']
      build_schemas(attrs['schemas'])
    end

    def build_schemas(schemas)
      return if schemas.nil?

      @schemas_data = schemas

      if @schemas_data.is_a? Hash
        @schemas = CatalogSchemas.new(schemas)
      end
    end

    def valid?
      return @valid if defined? @valid

      validate!
      validate_schemas!
      @valid = errors.empty?
    end

    delegate :cc_service, to: :catalog_service

    private

    def validate!
      validate_string!(:broker_provided_id, broker_provided_id, required: true)
      validate_string!(:name, name, required: true)
      validate_description!(:description, description, required: true)
      validate_hash!(:metadata, metadata) if metadata
      validate_bool!(:free, free) if free
      validate_bool!(:bindable, bindable) if bindable
      validate_hash!(:schemas, @schemas_data) if @schemas_data
    end

    def validate_schemas!
      if schemas && !schemas.valid?
        errors.add_nested(schemas, schemas.errors)
      end
    end

    def human_readable_attr_name(name)
      {
        broker_provided_id: 'Plan id',
        name:               'Plan name',
        description:        'Plan description',
        metadata:           'Plan metadata',
        free:               'Plan free',
        bindable:           'Plan bindable',
        schemas:            'Plan schemas',
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
