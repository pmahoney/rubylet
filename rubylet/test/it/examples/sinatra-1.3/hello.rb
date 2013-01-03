require 'sinatra'
require 'rubylet/session/container_store'

$started_at = "#{Time.now} (rand:#{rand(10000)})"

disable :logging
use Rubylet::Session::ContainerStore

get '/' do
  "tests/index: Hello, world! - from Sinatra"
end

get '/started_at' do
  $started_at.to_s
end

get '/session_values/:key' do
  key = params[:key]
  session[key].inspect
end

put '/session_values/:key' do
  key = params[:key]
  value = params[:value]
  if key && value
    session[key] = value
    'ok'
  else
    [400, 'missing key or value']
  end
end

get '/tests/log' do
  logger.info 'log requested'
end

# Hey Sinatra, we support async.callback without EventMachine!
require 'thread'
module EventMachine
  @q = Queue.new

  @reactor = Thread.new do
    while task = @q.pop
      begin
        task.call
      rescue => e
        puts e
      end
    end
  end

  def self.next_tick(&block)
    @q << block
  end

  def self.defer(&block)
    Thread.new &block
  end

  def self.schedule(&block)
    if @reactor.equal?(Thread.current)
      block.call
    else
      @q << block
    end
  end
end

get '/tests/stream' do
  stream do |out|
    out << "It's gonna be legen -"
    sleep 0.1
    out << " (wait for it) "
    sleep 0.1
    out << "- dary!"
  end
end

get '/tests/stream_keep_open' do
  stream(true) do |out|
    out << "It's gonna be legen -"
    sleep 0.1
    out << " (wait for it) "
    sleep 0.1
    out << "- dary!"
    Thread.new do
      sleep 0.2
      out.close
    end
  end
end
