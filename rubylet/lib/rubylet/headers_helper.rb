module Rubylet
  # Some methods to help with header names in Rack-land and Servlet-land
  module HeadersHelper
    RACK_CONTENT_LENGTH    = 'CONTENT_LENGTH'.freeze
    RACK_CONTENT_TYPE      = 'CONTENT_TYPE'.freeze
    RACK_PREFIX            = 'HTTP_'.freeze
    RACK_SEPARATOR         = '_'.freeze
    SERVLET_CONTENT_LENGTH = 'Content-Length'.freeze
    SERVLET_CONTENT_TYPE   = 'Content-Type'.freeze
    SERVLET_SEPARATOR      = '-'.freeze

    def equals_ignore_case?(s1, s2)
      s1.casecmp(s2) == 0
    end

    # Convert an HTTP_* header key into a Servlet-land key by stripping
    # 'HTTP_', and replacing '_' with '-'.  Headers in Servlet-land are
    # case insensitive, so there is no need to title-case header words.
    #
    # Content-Type and Content-Length do not have the HTTP_ prefix in
    # Rack-land and are correctly converted.
    #
    # If the header is not recognized as an HTTP header, nil is
    # returned.
    #
    # FIXME: This conversion will be incorrect if the header name
    # contains underscores and not dashes Hopefully example failures may
    # be worked around.
    #
    # @param [String] name
    # @return [String] a Servlet-land HTTP header name or nil
    def rack2servlet(name)
      if equals_ignore_case?(RACK_CONTENT_LENGTH, name)
        SERVLET_CONTENT_LENGTH
      elsif equals_ignore_case?(RACK_CONTENT_TYPE, name)
        SERVLET_CONTENT_TYPE
      elsif name.start_with?(RACK_PREFIX)
        name[5..-1].gsub(RACK_SEPARATOR, SERVLET_SEPARATOR)
      end
    end

    # Do not pass in Content-Type or Content-Length as these are used
    # raw in Rack land.
    #
    # @param [String] name
    # @return [String] a Rack-land HTTP header name
    def servlet2rack(name)
      if equals_ignore_case?(SERVLET_CONTENT_LENGTH, name)
        RACK_CONTENT_LENGTH
      elsif equals_ignore_case?(SERVLET_CONTENT_TYPE, name)
        RACK_CONTENT_TYPE
      else
        RACK_PREFIX + name.upcase.gsub(SERVLET_SEPARATOR, RACK_SEPARATOR)
      end
    end
  end
end
