module CloudController
  class Constants
    API_VERSION = File.read(File.expand_path('../../config/version_v2', File.dirname(__FILE__))).strip.freeze
    API_VERSION_V3 = File.read(File.expand_path('../../config/version', File.dirname(__FILE__))).strip.freeze
    NGINX_UPLOAD_MODULE_DUMMY = '<ngx_upload_module_dummy>'.strip.freeze
  end
end
