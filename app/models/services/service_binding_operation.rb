module CloudController
  class ServiceBindingOperation < Sequel::Model
    export_attributes :state, :description, :updated_at, :created_at

    def update_attributes(attrs)
      self.set attrs
      self.save
    end
  end
end
