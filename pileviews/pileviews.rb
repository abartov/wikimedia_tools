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

VERSION = "0.1 2016-05-10"

def usage 
  puts <<EOF
pagepile - generate a CSV with pageview data from a given PagePile ID, version #{VERSION}

Usage:

$ ruby pagepile.rb <PagePile ID>

For example:

$ ruby pagepile.rb 3306

The tool will create (and overwrite!) a file named "pagepile_<id>.csv" in the current directory, 
where <id> is the provided PagePile ID.

Report bugs to Asaf Bartov, asaf.bartov@gmail.com
EOF
  exit
end

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

usage if ARGV[0].nil? or ARGV[0].empty?

print "Getting article list by PagePile ID #{ARGV[0]}... "
articles = get_articles(ARGV[0])
print "done!\nGetting pageviews... "
i = 0
views = []
today = Date.today.to_s.gsub('-','')
articles['pages'].each {|art|
  i += 1
  views << { :art => art, :views => get_views(art, articles['wiki'],today) }
  print "#{i}... " if i % 10 == 0
}

print "done!\nWriting CSV file pagepile_#{ARGV[0]}.csv... "
# TODO: write CSV
File.open("pagepile_#{ARGV[0]}.csv",'w') {|f|
  # emit month headings first
  line = 'Article name,'
  views[0][:views].each {|v|
    line += "#{v[0][0..3]}-#{v[0][4..5]},"
  }
  line += 'Total'
  f.puts(line) 
  views.each {|v|
    total = 0
    line = "\"#{v[:art]}\","
    next if v[:views].nil?
    v[:views].each {|vv|
      line += "#{vv[1]},"
      total += vv[1] unless vv[1].nil? 
    }
    line += total.to_s
    f.puts(line)
  }
}
puts "done!"

