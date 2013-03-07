require 'rubylet/session/container_store'

# see http://polycrystal.org/2012/04/15/asynchronous_responses_in_rack.html

class MyServlet
  def init(servlet_context); end

  def destroy; end

  def service(req, resp)
    resp.setStatus(200)
    resp.setHeader 'Content-Type', 'text/plain'
    resp.getWriter.write 'tests/index hello, world'
  end
end

class DeferredBody
  def each(&block)
    # normally we'd yield each part of the body, but since
    # it isn't available yet, we save &block for later
    @server_block = block
  end

  def send(data)
    # calling the saved &block has the same effect as
    # if we had yielded to it
    @server_block.call data
  end
end

class MyApp
  def call(env)
    txt = handle(env).to_s
    headers = {
      'Content-Type' => 'text/plain',
      'Content-Length' => txt.size.to_s
    }
    [200, headers, [txt]]
  end

  def handle(env)
    case env['PATH_INFO']
    when %r{/session_values/(.*)}
      if env['REQUEST_METHOD'] == 'POST'
        input = env['rack.input'].read

        params = {}
        # very crummy params parser
        pairs = input.split('&').each do |pair|
          kv = pair.split('=')
          params[kv[0]] = kv[1]
        end

        env['rack.session'][$1] = params['value']
        
      else
        env['rack.session'][$1]
      end
    when %r{/tests/large/(.*)}
      size = $1.to_i
      'a' * size
    when %r{/tests/delay}
      # simple delayed response using async
      cb = env['async.callback']

      Thread.new do
        sleep 0.1               # long task, wait for message, etc.
        cb.call [200, {'Content-Type' => 'text/plain'}, ['delayed!']]
        cb.call [0, {}, []]
      end
      
      throw :async
    when %r{/tests/stream}
      # streamed body
      cb = env['async.callback']

      body = DeferredBody.new

      cb.call [200, {'Content-Type' => 'text/plain'}, body]

      Thread.new do
        sleep 0.1
        body.send 'Hello, '
        sleep 0.1
        body.send 'World'
        sleep 0.1
        cb.call [0, {}, []]
      end

      throw :async
    else
      'tests/index hello, world'
    end
  end
end

use Rubylet::Session::ContainerStore
run MyApp.new
