require "cloud_controller/buildpack_positioner"

module VCAP::CloudController
  class Buildpack < Sequel::Model
    export_attributes :name, :position, :enabled, :locked, :filename
    import_attributes :name, :position, :enabled, :locked, :filename, :key

    def self.list_admin_buildpacks
      exclude(:key => nil).exclude(:key => "").order(:position).all
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

    def self.locked_last_position
      last = at_last_position
      last.lock!
      last.position
    end

    def self.create(values = {}, &block)
      last = Buildpack.at_last_position

      if last
        positioner = BuildpackPositioner.new
        positioner.create(values, &block)
      else
        super(values) do |instance|
          block.yield(instance) if block
          instance.position = 1
        end
      end
    end

    def self.update(buildpack, updated_attributes = {})
      @db.transaction(savepoint: true) do
        buildpack.lock!

        normalized_attributes = if updated_attributes.has_key?("position")
          positioner = BuildpackPositioner.new
          normalized_position = positioner.normalize(buildpack, updated_attributes["position"])
          updated_attributes.merge("position" => normalized_position)
        else
          updated_attributes
        end

        buildpack.update_from_hash(normalized_attributes)
      end

      buildpack
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def after_destroy
      super

      positioner = BuildpackPositioner.new
      positioner.shift_positions_down(self)
    end

    def validate
      validates_unique :name
      validates_format(/^(\w|\-)+$/, :name, message: "name can only contain alphanumeric characters")
    end

    def locked?
      !!locked
    end

    def staging_message
      {buildpack_key: self.key}
    end

    def to_json
      Yajl::Encoder.encode name
    end

    def custom?
      false
    end
  end
end
