require 'builder'
require 'rubylet/builder_alias_tag'
require 'rubylet/builder_defaults'

module Rubylet
  class JettyDescriptorBuilder < ::Builder::XmlMarkup
    extend BuilderAliasTag
    include BuilderDefaults

    alias_tag 'Configure'
    alias_tag 'Set'

    def initialize(opts = {})
      super(opts)
      declare!(:DOCTYPE, :Configure, :PUBLIC,
               '-//Jetty//Configure//EN',
               'http://www.eclipse.org/jetty/configure.dtd')
    end

    def configure!(&block)
      configure :class => 'org.eclipse.jetty.webapp.WebAppContext', &block
    end

    def set!(name, value)
      set value, :name => name
    end
  end
end
