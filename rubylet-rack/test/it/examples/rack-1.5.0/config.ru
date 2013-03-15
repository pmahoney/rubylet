require 'rubylet/rack/session/container_store'

# see http://polycrystal.org/2012/04/15/asynchronous_responses_in_rack.html

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
  # Respond with plain text
  def txt(txt)
    headers = {
      'Content-Type' => 'text/plain',
      'Content-Length' => txt.size.to_s
    }
    [200, headers, [txt]]
  end

  def call(env)
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
      end

      txt(env['rack.session'][$1] || '')
    when %r{/tests/delay}
      # simple delayed response using async
      cb = env['async.callback']

      Thread.new do
        sleep 0.1               # long task, wait for message, etc.
        cb.call txt('delayed!')
        cb.call [0, {}, []]
      end
      
      throw :async
    when %r{/tests/large/(.*)}
      size = $1.to_i
      txt('a' * size)
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
    when %r{/tests/hijack-partial}
      headers = {}
      headers["Content-Type"] = "text/plain"
      headers['X-Rubylet-Integration-Test'] = 'true'
      headers["rack.hijack"] = lambda do |io|
        # This lambda will be called after the app server has outputted
        # headers. Here we can output body data at will.
        begin
          10.times do |i|
            io.write("Line #{i + 1}!\n")
            io.flush
            puts 'flush!'
            sleep 0.1
          end
        ensure
          puts "closing!"
          io.close
        end
      end
      [200, headers, nil]
    else
      txt('tests/index hello, world')
    end
  end
end

use Rack::Lint
use Rubylet::Rack::Session::ContainerStore
use Rack::Lint
run MyApp.new
