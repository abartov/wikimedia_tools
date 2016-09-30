#!/usr/bin/env ruby
#
# stats for May Hachem
#
# an ad-hoc hack by Asaf Bartov <asaf.bartov@gmail.com>
#
# tested on Ruby 2.3. 

require 'rubygems'
require 'mediawiki_api'

START_DATE = Date.new(2016,8,11)
#START_DATE = Date.new(2016,7,12)
END_DATE = Date.new(2016,8,12)

def delta_for_article(mw, art)
  r = mw.query(prop: 'revisions', titles:art, rvprop:'timestamp|size', rvlimit:500) # assume it's within the last 500 revs...
  begin
    if r.data['pages'].keys.first == '-1'
      puts "\n--> red link: #{art}"
      return -99999
    end
    revs = r.data['pages'].first[1]['revisions']
    cursize = revs[0]['size']
    last_relevant_rev = nil
    first_relevant_rev = nil
    revs.each {|rev|
      revdate = Date.parse(rev['timestamp'])
      if revdate >= START_DATE and revdate <= END_DATE
        last_relevant_rev = rev if last_relevant_rev.nil?
        first_relevant_rev = rev # keep assigning revs until we find one that's outside the range, or end up with the creation of the article
      else
        next if last_relevant_rev.nil? # haven't reached the interested revs yet; keep looking
        first_relevant_rev = rev # mark this latest rev *outside* the desired range, and stop
        break
      end
    }
    unless first_relevant_rev.nil? and last_relevant_rev.nil?
      return last_relevant_rev['size'] - first_relevant_rev['size']
    else
      return 0
    end
  rescue
    puts "\n! ERROR handling [[#{art}]]\n"
    return -99999
  end
end

# main

# initialize resources
mw = MediawikiApi::Client.new("https://en.wikipedia.org/w/api.php")
puts "reading article names..."
lines = File.open('raw_article_names.txt','r').read.split("\n")
print "gathering statistics... "
count = 0
articles = {}
lines.each {|l|
  if l =~ /\[\[(.*?)\]\]/
    print "#{count}... " if count % 20 == 1
    articles[$1] = delta_for_article(mw, $1)
  end
  count += 1
}
File.open('stats_for_may.txt','w') {|f|
  count = 1
  articles.keys.sort.each {|art|
    next if articles[art] == -99999
    f.puts "#{count},#{art.gsub(',','\,')},#{articles[art]}"
    count += 1
  }
}
puts "done!"

exit 0

