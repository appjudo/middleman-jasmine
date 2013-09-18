require 'middleman-core'

module Jasmine
  class Configuration
    attr_reader :src_files
  end
end

module Middleman
  module Jasmine
    class << self
      def registered(app, options_hash={}, &block)
        app.send :include, InstanceMethods

        options = OpenStruct.new(default_options.merge(options_hash))

        yield options if block_given?

        jasmine_app = init_jasmine_app(options)
        sprockets_app = init_sprockets_app || jasmine_app

        app.map(::Jasmine.config.spec_path) { run sprockets_app }
        app.map(options.jasmine_url) { run jasmine_app }
      end

      private

      PATH_METHOD_NAMES = [:jasmine_path, :spec_path, :boot_path]

      def init_jasmine_app(options = {})
        ::Jasmine.initialize_config
        PATH_METHOD_NAMES.each do |get_method_name|
          path = options.jasmine_url + ::Jasmine.config.send(get_method_name)
          set_method_name = "#{get_method_name}=".to_sym
          ::Jasmine.config.send(set_method_name, path)
        end

        ::Jasmine.load_configuration_from_yaml(options.jasmine_config_path)

        config = ::Jasmine.config.clone
        config.add_rack_path(config.src_path, lambda {
          Rack::Jasmine::Runner.new(::Jasmine::Page.new(config))
        })
        src_files = config.src_files.call.map do |path|
          path.sub(/(\.js)?\.coffee\Z/, '.js')
        end
        config.src_files = lambda { src_files }

        ::Jasmine::Application.app(config).clone
      end

      def init_sprockets_app
        if defined?(::Sprockets::Environment)
          new_sprockets_app = ::Sprockets::Environment.new
          new_sprockets_app.append_path(::Jasmine.config.spec_dir)
          new_sprockets_app
        end
      end

      def default_options
        {
          jasmine_url: "/jasmine",
          jasmine_config_path: nil, # use Jasmine default
          fixtures_dir: "spec/javascripts/fixtures"
        }        
      end

      alias :included :registered
    end

    module InstanceMethods
    end
  end
end

# monkey patch Rack::Jasmine::Runner to allow for paths other than /
module Rack
  module Jasmine
    class Runner
      def call(env)
        @path = env["PATH_INFO"]
        [
          200,
          { 'Content-Type' => 'text/html'},
          [@page.render]
        ]
      end      
    end
  end
end