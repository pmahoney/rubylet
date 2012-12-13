module Rubylet
  module BuilderAliasTag
    def alias_tag(tag_name, method_name = tag_name.downcase.gsub('-', '_'))
      define_method(method_name.to_sym) do |*args, &block|
        tag!(tag_name, *args, &block)
      end
    end
  end
end
