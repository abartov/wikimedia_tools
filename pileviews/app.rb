# app.rb

require 'sinatra'
require 'tempfile'
require './pileviewslib'

configure do
  set :bind, '0.0.0.0'
  set :port, ENV['PILEVIEWS_PORT']
end
get '/pileviews' do
  haml :index
end

post '/pileviews/make_csv' do
  fname = "pileviews_#{params[:pile_id]}"
  temp_file = Tempfile.new(fname)
  temp_file.write(pileviews_csv(params[:pile_id]))
  temp_file.close # NOTE: file will be automatically deleted when temp_file is garbage-collected
  send_file temp_file.path, filename: fname+'.csv', type: 'text/csv'
#  content_type 'text/csv'
#  views = pileviews_csv(params[:pile_id])
  #send_data views, filename: "pagepile_#{params[:pile_id]}.csv", type: 'text/csv'
end
