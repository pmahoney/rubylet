module Rubylet
  # Helper module for sending a response to a
  # +java.servlet.http.HttpServletResponse+ object.
  module Respond
    # Send response data.  The status and headers may only be sent
    # once.  The body may be sent in parts; for the second and
    # subsequent calls to +#respond+, status must be +<= 0+.
    #
    # @param [java.servlet.http.HttpServletResponse] resp
    # @param [Rubylet::Environment] env currently not used
    # @param [Fixnum] status the response status, or zero to ignore
    # @param [Hash] headers http headers that will be set
    # @param [Array] body an array-like object for iterating through the body
    def respond(resp, env, status, headers, body)
      # status > 0 indicates initial response with status and
      # headers; subsequent responses must have status <= 0.
      if status > 0
        resp.setStatus(status)

        headers.each do |k, v|
          resp.setHeader k, v
        end
      end

      if body.respond_to? :to_path
        #env['rack.logger'].warn {
        #  "serving static file with ruby: #{body.to_path}"
        #}

        # TODO: faster to user pure java implementation?  Probably better to
        # either not have ruby serve static files or to put some cache out
        # front.
        write_body(body, resp.getOutputStream) { |part| part.to_java_bytes }
      else
        write_body(body, resp.getWriter)
      end

      # Flush the buffer and commit the response.  If this is an async
      # response, only the headers and any available body will be sent
      # to the client.
      resp.flushBuffer
    end

    # Write each part of body with writer.  Optionally transform each
    # part with the given block.  Ensure body is closed if it responds
    # to :close.
    #
    # TODO: Currently the body is not flushed after each part.  For an
    # async streaming response using the inside-out technique, that
    # means each async part won't be flushed, which probably isn't
    # desired.
    def write_body(body, writer)
      begin
        body.each do |part|
          writer.write(block_given? ? yield(part) : part)
        end
      ensure
        body.close if body.respond_to?(:close) rescue nil
      end
    end
  end
end
