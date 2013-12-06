#!ruby 
#
# This script takes the manually-saved and roughly cleaned 
# contents of the OSU Hebrew Literature Bio-Bibliographical Lexicon 
# at https://library.osu.edu/projects/hebrew-lexicon/
# and generates a tab-separated-file (TSV) with URLs, Hebrew labels,
# and (where available) English labels and Hebrew/English Wikipedia article URLs.
#
# For convenience, it also generates two lists of URLs, of items without 
# Hebrew/English Wikipedia articles
#
# Written by Asaf Bartov <asaf.bartov@gmail.com>
#
# Last updated: Dec 5th 2013

require 'rubygems'
require 'debugger'
require 'net/http'
require 'nokogiri'
require 'uri'
require 'media_wiki'

URLBASE = 'https://library.osu.edu/projects/hebrew-lexicon/'
$mwcount = 0
$count = 0
$total = 0
$tot_hewp = 0
$tot_enwp = 0
$tot_enwp_from_hewp = 0
$no_hewp = []
$no_enwp = []
$enwp_but_not_hewp = []

# ensure we respect the Wikipedia servers
def throttle
  $mwcount += 1
  if $mwcount % 150 == 0
    puts "Pausing to respect the Wikipedia servers... :)"
    sleep(15) 
  end
end

def transpose(s)
  # ...
end

def log(s)
  $ferr.puts(s)
  puts(s)
end
def trim(s)
  s.gsub("\n", ' ').gsub("\r", ' ').gsub("\302\240", ' ').gsub("\t", ' ').gsub(/\(\d+[-־]?\d*\)/,'').squeeze(' ').strip
end
# returns [hebrew_title, english_title]
# (this makes ridiculously fragile assumptions about the current actual HTML structure of the Lexicon, obviously)
def titles_from_page(page)
  doc = Nokogiri::HTML(page)
  cells = doc.xpath('//table[@id="table5"]/tr/td')
  if cells.empty?
    cells = doc.xpath('//table[@id="table4"]/tr/td') # ridiculous, I know
    if cells.empty?
      cells = doc.xpath('//table[@id="table2"]/tr/td') # ridiculouser, I know
    end
  end
  he, en = ['', '']
  begin
    he, en = [trim(cells[0].text()), trim(cells[-1].text())] # first and last <td> elements should be the Hebrew and English names.  There may or may not be the "in preparation" notice in a middle <td>
  rescue Exception
    log("--> ERROR getting labels!")
  end
  return [he, en]
end

def hewp(page, title, mw, count)
  # first see if there's an explicit link to Hebrew Wikipedia
  if page =~ /http[s?]:\/\/he.wikipedia.org\/wiki\/.*?"/
    $tot_hewp += 1 if count
    return $&[0..-2]
  else
      # no match, so let's query Wikipedia using the given title and hope for the best
    begin
      articles = mw[0].list(title)
    rescue Exception
      log("ERROR in title: #{title}")
      return ''
    end
    throttle
    if articles.length > 0
      $tot_hewp += 1 if count
      return "https://he.wikipedia.org/wiki/#{articles[0]}" 
    end
    return ''
  end
end
def enwp_from_hewp(page, title, mw)
  art = hewp(page, title, mw, false)
  return nil if art == ''
  title = /wiki\/(.*)/.match(art).captures[0]
  eng_title = mw[0].langlink_for_lang(title, 'en')
  throttle
  return nil if eng_title.nil?
  $tot_enwp_from_hewp += 1
  return "https://en.wikipedia.org/wiki/#{eng_title}"
end
def enwp(page, titles, mw, hewp_found)
  # first try querying English Wikipedia
  unless titles[1].empty?
    begin
      articles = mw[1].list(titles[1])
    rescue Exception
      log("ERROR in title: #{titles[1]}")
      return ''
    end
    throttle
    if articles.length > 0
      $tot_enwp += 1
      $enwp_but_not_hewp << titles[1] unless hewp_found
      return "https://en.wikipedia.org/wiki/#{articles[0]}" if articles.length > 0
    end
    # no luck, but there's a small chance it does exist with a different spelling, and has an interwiki link from the Hebrew Wikipedia, if that exists
    article = enwp_from_hewp(page, titles[0], mw)
    
    return article unless article.nil?
  end
  # give up
  return ''
end

def slurp(url)
  res = Net::HTTP.get_response(URI.parse(url))
  unless res.code == '200'
    log("Error slurping URL #{url}");
    return '' 
  end 
  return res.body
end

def process(m, mw)
  #title = transpose(m.captures[1].gsub("\n",' ').gsub('  ', ' '))
  url = URLBASE+m.captures[0]
  page = slurp(url)
  $count += 1
  titles = titles_from_page(page)
  log("#{$count}/#{$total}; HEWP #{$tot_hewp}; ENWP #{$tot_enwp}+#{$tot_enwp_from_hewp} - #{titles[0].reverse} - #{url}")
  h = hewp(page, titles[0], mw, true)

  if h == ''
    $no_hewp << [url, titles[0]] 
    e = enwp(page, titles, mw, false)
  else
    e = enwp(page, titles, mw, true)
  end
  $no_enwp << [url, titles[1]] if e == ''
  return [url, titles[0], titles[1], h, e].map {|s| s.force_encoding('UTF-8') }
end

# tmp 
#tmplist = File.open('osu_lexicon_no_hewp_urls.txt', 'r').read
#i = 0
#File.open('hewp_to_post.txt', 'w') {|f|
#  tmplist.split("\n").each {|url|
#    puts "...#{i}" if i % 20 == 0 
#    i += 1
#    titles = titles_from_page(slurp(url))
#    f.puts("#{titles[0]} - [#{url} בלקסיקון]")
#  }    
#}
#exit

# main
mw = [MediaWiki::Gateway.new('http://he.wikipedia.org/w/api.php'), MediaWiki::Gateway.new('http://en.wikipedia.org/w/api.php')]

#raw_html = File.open('tmpraw','r').read # slurp the file # TESTING
raw_html = File.open('osu_lexicon_raw_html_bit','r').read # slurp the file
matches = raw_html.to_enum(:scan, /<a href="(\d+\.php)".*?>(.*?)</m).map { Regexp.last_match }
$total = matches.count

# bulk of work happens here
$ferr = File.open('osu_lexicon_errors.log', 'w')
items = matches.map {|m| process(m, mw) }

#items.each {|item|
#  puts "url: #{item[0]} - he label: #{item[1]} - en label: #{item[2]} - hewp: #{item[3]} - enwp: #{item[4]}"
#}

# output
puts "Writing output..."
File.open('osu_lexicon.tsv', 'wb') {|f|
  items.each {|item| f.puts(item[0]+"\t"+item[1]+"\t"+item[2]+"\t"+item[3]+"\t"+item[4]) }
}
buf = ''
$no_hewp.each {|h|
  buf += "# #{h[1]} - [#{h[0]} בלקסיקון]\n"
}
File.open('osu_lexicon_no_hewp_urls.txt', 'w') {|f| f.write(buf) }
File.open('osu_lexicon_no_enwp_urls.txt', 'w') {|f| f.write($no_enwp.join("\n")) }
File.open('osu_lexicon_enwp_but_not_hewp.txt', 'w') {|f| f.write($enwp_but_not_hewp.join("\n"))}

log("Done!")
$ferr.close
