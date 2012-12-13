require 'builder'
require 'rubylet/builder_alias_tag'
require 'rubylet/builder_defaults'

module Rubylet
  class WebappDescriptorBuilder < ::Builder::XmlMarkup
    extend BuilderAliasTag
    include BuilderDefaults

    # def self.alias_tag(tag_name, method_name = tag_name.downcase.gsub('-', '_'))
    #   define_method(method_name.to_sym) do |*args, &block|
    #     tag!(tag_name, *args, &block)
    #   end
    # end

    alias_tag 'web-app'

    alias_tag 'display-name'

    alias_tag 'listener'
    alias_tag 'listener-class'

    alias_tag 'filter-name'
    alias_tag 'filter-class'
    alias_tag 'filter-mapping'

    alias_tag 'servlet-name'
    alias_tag 'servlet-class'
    alias_tag 'servlet-mapping'
    alias_tag 'async-supported'
    alias_tag 'load-on-startup'

    alias_tag 'url-pattern'
    alias_tag 'context-param'
    alias_tag 'init-param'
    alias_tag 'param-name'
    alias_tag 'param-value'

    alias_tag 'resource-ref'
    alias_tag 'description'
    alias_tag 'res-ref-tag'
    alias_tag 'res-ref-name'
    alias_tag 'res-type'
    alias_tag 'res-auth'

    # Write a context param tag unless value is nil.
    def context_param!(name, value)
      return unless value
      context_param { |p|
        p.param_name name
        p.param_value value
      }
    end

    # Write an init param tag unless value is nil.
    def init_param!(name, value)
      return unless value
      init_param { |p|
        p.param_name name
        p.param_value value
      }
    end

    def listener!(klass)
      listener { |w| w.listener_class(klass) }
    end

    def web_app!(version, metadata_complete = true, &block)
      xmlns, schema_loc =
        case version.to_s
        when '2.5'
          j2ee = 'http://java.sun.com/xml/ns/j2ee'
          [j2ee, "#{j2ee}/web-app_2_5.xsd"]
        when '3.0'
          javaee = 'http://java.sun.com/xml/ns/javaee'
          [javaee, "#{javaee} #{javaee}/web-app_3_0.xsd"]
        else
          raise ArgumentError, "unknown java servlet version #{version}"
        end
      
      web_app('xmlns' => xmlns,
              'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
              'xsi:schemaLocation' => schema_loc,
              'version' => version.to_s,
              'metadata-complete' => metadata_complete,
              &block)
    end

  end
end
