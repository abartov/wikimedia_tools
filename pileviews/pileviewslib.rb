#!/usr/bin/env ruby
#
# pileviews - generate a CSV with pageview data from a given PagePile ID
#
# developed and maintained by Asaf Bartov <asaf.bartov@gmail.com>
#
# tested on Ruby 2.0.

require 'json'
require 'net/http'
require 'date'

def get_articles(pile_id)
  uri = URI("https://tools.wmflabs.org/pagepile/api.php?id=#{pile_id}&action=get_data&format=json")
  response = Net::HTTP.get(uri)
#  req = Net::HTTP::Get.new(uri)
#  req['Accept'] = 'application/json'
#  response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') {|http|
#    http.request(req)
#  } 
  JSON.parse(response)
end
def get_views(article, wikiname,today)
  wiki = wikiname.sub('wiki','').downcase
  uri = URI("https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/#{wiki}.wikipedia/all-access/all-agents/#{URI.escape(article)}/daily/2015080100/#{today}")
  response = Net::HTTP.get(uri)
  views = JSON.parse(response)['items']
  by_month = {}
  if views.nil?
    puts "nil returned for article #{article}\n\n#{uri}"
    return nil
  end
  views.each {|v|
    month = v['timestamp'][0..5] # YYYYMM
    by_month[month] = 0 if by_month[month].nil?
    by_month[month] += v['views']
  }
  return by_month
end

def pileviews_csv(pile_id)
  articles = get_articles(pile_id)
  views = []
  today = Date.today.to_s.gsub('-','')
  articles['pages'].each {|art| views << { :art => art, :views => get_views(art, articles['wiki'],today) } }
  output = []
  # emit month headings first
  line = 'Article name,'
  views[0][:views].each {|v|
    line += "#{v[0][0..3]}-#{v[0][4..5]},"
  }
  line += 'Total'
  output << line

  views.each {|v|
    total = 0
    line = "\"#{v[:art]}\","
    next if v[:views].nil?
    v[:views].each {|vv|
      line += "#{vv[1]},"
      total += vv[1] unless vv[1].nil? 
    }
    line += total.to_s
    output << line
  }
  return output.join("\n")
end

def pileviews(pile_id)
  File.open("pagepile_#{pile_id}.csv", 'w') {|f| f.puts(pileviews_csv(pile_id))}
end
#class RequestController
#  def call(env)
#    [200, {}, ["Hello World"]]
#  end
#end
