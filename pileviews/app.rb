# app.rb

require 'sinatra'
configure do
  set :bind, '0.0.0.0'
  set :port, ENV['PILEVIEWS_PORT']
end
get '/' do
  'Hello world!'
end

