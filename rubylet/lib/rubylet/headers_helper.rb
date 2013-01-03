module Rubylet
  # Some methods to help with header names in Rack-land and Servlet-land
  module HeadersHelper
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
      if name =~ /Content_(Type|Length)/i
        name.gsub('_', '-')
      elsif name.start_with?('HTTP_')
        name[5..-1].gsub('_', '-')
      end
    end

    # Do not pass in Content-Type or Content-Length as these are used
    # raw in Rack land.
    #
    # @param [String] name
    # @return [String] a Rack-land HTTP header name
    def servlet2rack(name)
      if name =~ /Content-(Type|Length)/i
        name
      else
        'HTTP_' + name
      end.upcase.gsub('-', '_')
    end
  end
end
