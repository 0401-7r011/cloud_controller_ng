require 'messages/list_message'

module CloudController
  class PackagesListMessage < ListMessage
    register_allowed_keys [:page, :per_page, :order_by, :states, :types, :guids, :app_guids, :app_guid, :space_guids, :organization_guids]

    validates_with NoAdditionalParamsValidator

    validates :states, array: true, allow_nil: true
    validates :types,  array: true, allow_nil: true
    validates :guids,  array: true, allow_nil: true
    validates :app_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validate :app_nested_request, if: -> { app_guid.present? }

    def self.from_params(params)
      opts = params.dup
      %w(types states guids app_guids space_guids organization_guids).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by, :app_guid])
    end

    private

    def app_nested_request
      invalid_guids = []
      invalid_guids << :app_guids if app_guids
      invalid_guids << :organization_guids if organization_guids
      invalid_guids << :space_guids if space_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_guids.join("', '")}'") if invalid_guids.present?
    end
  end
end
