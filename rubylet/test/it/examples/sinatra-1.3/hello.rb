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
