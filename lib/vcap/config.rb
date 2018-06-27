require 'yaml'
require 'membrane'

class Config
  class << self
    attr_reader :schema

    def define_schema(&blk)
      @schema = Membrane::SchemaParser.parse(&blk)
    end

    def from_file(filename, symbolize_keys=true)
      config = YAML.load_file(filename)
      config = deep_symbolize_keys_except_in_arrays(config) if symbolize_keys
      @schema.validate(config)
      config
    end

    private

    def deep_symbolize_keys_except_in_arrays(hash)
      return hash unless hash.is_a? Hash

      hash.each.with_object({}) do |(k, v), new_hash|
        new_hash[k.to_sym] = deep_symbolize_keys_except_in_arrays(v)
      end
    end
  end
end
