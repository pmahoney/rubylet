require 'sinatra'

$started_at = "#{Time.now} (rand:#{rand(10000)})"

get '/hi' do
  "Hello, world! - from Sinatra"
end

get '/started_at' do
  $started_at.to_s
end
