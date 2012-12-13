require 'builder'
require 'rubylet/builder_alias_tag'
require 'rubylet/builder_defaults'

module Rubylet
  class GlassfishDescriptorBuilder < ::Builder::XmlMarkup
    extend BuilderAliasTag
    include BuilderDefaults

    alias_tag 'glassfish-web-app'
    alias_tag 'resource-ref'
    alias_tag 'res-ref-name'
    alias_tag 'jndi-name'

    def initialize(opts = {})
      super(opts)
      @alt_root_count = 0
      declare!(:DOCTYPE, :'glassfish-web-app', :PUBLIC,
               '-//GlassFish.org//DTD GlassFish Application Server 3.1 Servlet 3.0//EN',
               'http://glassfish.org/dtds/glassfish-web-app_3_0-1.dtd')
    end

    def alternate_doc_root!(from, dir)
      @alt_root_count += 1
      property(:name => "alternatedocroot_#{@alt_root_count}",
               :value => "from=#{from} dir=#{dir}")
    end
  end
end
