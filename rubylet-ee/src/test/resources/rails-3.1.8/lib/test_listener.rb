require 'thread'
require 'pp'

class TestListener
  include Java::JavaxServlet::ServletContextListener

  NAME = 'test_listener.queue'
  STOP = Object.new.freeze

  def contextInitialized(event)
    context = event.servlet_context
    queue = Queue.new
    context.set_attribute(NAME, queue)
    context.get_attribute('test_status').started = true

    t = Thread.new do
      loop do
        begin
          if queue.pop(true) == STOP
            context.set_attribute(NAME, nil)
            break
          end
        rescue ThreadError
          # queue was empty; do some work
          sleep 0.1
        end
      end
    end
  end

  def contextDestroyed(event)
    if q = event.servlet_context.get_attribute(NAME)
      q.push STOP
      event.servlet_context.get_attribute('test_status').stopped = true
    end
  end
end
