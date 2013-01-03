module Rubylet
  # Helper module for sending a response to a
  # +java.servlet.http.HttpServletResponse+ object.
  module Respond
    # Send response status, headers, and body.
    #
    # The body will be closed if it responds to +:close+.
    #
    # @param [java.servlet.http.HttpServletResponse] resp
    # @param [Rubylet::Environment] env currently not used
    # @param [Fixnum] status the response status, or zero to ignore
    # @param [Hash] headers http headers that will be set
    # @param [Array] body an array-like object for iterating through the body
    def respond(resp, env, status, headers, body)
      respond_headers(resp, status, headers)

      if body.respond_to? :to_path
        # TODO: faster to user pure java implementation?  Probably
        # better to either not have ruby serve static files or to put
        # some cache out front.  See about using the file channel like
        # jruby-rack.
        write_body(body, resp.getOutputStream) { |part| part.to_java_bytes }
      else
        write_body(body, resp.getWriter)
      end
    ensure
      body.close if body.respond_to?(:close) rescue nil
    end

    # Send response status, headers, and any body parts given.  May be
    # called multiple times on the same response.  The status and
    # headers will only be sent on the first call. For the second and
    # subsequent calls, status must be +<= 0+.
    #
    # The output stream will be flushed on the first call and after
    # each body part.
    #
    # @param [java.servlet.http.HttpServletResponse] resp
    # @param [Fixnum] status the response status, or zero to ignore
    # @param [Hash] headers http headers that will be set
    # @param [Array] body an array-like object for iterating through the body
    def respond_multi(resp, status, headers, body)
      if status > 0
        respond_headers(resp, status, headers)
        write_body_flush(body, resp.getWriter)
        resp.flushBuffer        # just in case initial body was empty
      else
        write_body_flush(body, resp.getWriter)
      end
    end

    # Set the status and headers.  Do not flush the buffer or commit
    # the response.
    #
    # @param [java.servlet.http.HttpServletResponse] resp
    # @param [Fixnum] status
    # @param [Hash<String,String>] headers
    def respond_headers(resp, status, headers)
      resp.setStatus(status)
      headers.each do |k, v|
        resp.setHeader k, v
      end
    end

    # Write each part of body with writer.  Optionally transform each
    # part with the given block.
    def write_body(body, writer)
      body.each do |part|
        writer.write(block_given? ? yield(part) : part)
      end
    end

    # Write each part of body with writer.  Optionally transform each
    # part with the given block.  Flush the response after each part.
    def write_body_flush(body, writer)
      body.each do |part|
        writer.write(block_given? ? yield(part) : part)
        writer.flush
      end
    end
  end
end
