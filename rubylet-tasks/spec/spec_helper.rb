if RUBY_VERSION =~ /^1.8/
  require 'rubygems'
  gem 'minitest'
end

require 'minitest/autorun'
require 'minitest/matchers/version' # workaround minitest/matchers'
                                    # failure to define
                                    # Minitest::Matchers
require 'minitest/matchers'

# Validation matcher of XMl text against a schema.  TODO: should fetch
# and report line number from underlying java exception.
#
# Requires Java.
class Validate
  attr_reader :schema_url

  attr_accessor :schema_url, :error

  def initialize(schema_url)
    @schema_url = schema_url
  end

  def failure_message
    " expected no errors but got #{error}"
  end

  def negative_failure_message
    ' expected errors but got none'
  end

  def description
    "validate against XML schema #{schema_url}"
  end

  def matches?(subject)
    factory =
      Java::JavaxXmlValidation::SchemaFactory.newInstance('http://www.w3.org/2001/XMLSchema')
  
    url = Java::JavaNet::URL.new(schema_url)
    schema = factory.newSchema(url)
    validator = schema.newValidator
    reader = Java::JavaIO::StringReader.new(subject.to_s)
    source = Java::JavaxXmlTransformStream::StreamSource.new(reader)
    
    begin
      validator.validate(source)
      true
    rescue => e
      self.error = e.message
      false
    end
  end
end

Minitest::Test.register_matcher Validate, :validate
