require 'messages/list_message'

module VCAP::CloudController
  class DeploymentsListMessage < ListMessage
    register_allowed_keys [
      :app_guids,
      :states,
    ]

    validates_with NoAdditionalParamsValidator

    validates :app_guids, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(app_guids states))
    end
  end
end
