# quick script to scrape public domain photos by Zoltan Kluger from the Israeli National Archive, with metadata, for uploading to Commons
# by Asaf Bartov <asaf.bartov@gmail.com>, March 2017
# tested on Ruby 2.2

require 'watir'
require 'byebug'
require 'csv'
require 'getoptlong'
require 'sqlite3'

def grab_item_popup(box, year)
  img = box.imgs[0]
  alt = img.alt
  thumb_url = img.src
  anchor = box.a
  if anchor.exist?
    anchor.click
    item_url = box.a(:class => 'search-image-read-more').href
    download_url = box.a(:class => 'search-image-icon download').href
    @data[year] << {item_url: item_url, download_url: download_url, thumb_url: thumb_url, description: alt, year: year}
  end
  # dismiss popup
  close = box.span(:class => 'popup-close')
  close.exist?
  close.click
end

puts "Starting Watir and Firefox"
@totals = {}
@data = {}
browser = Watir::Browser.new :firefox
(1939..1940).each {|year|
#(1939..1974).each {|year|
  puts "Accessing Kluger archive for year #{year}"
  browser.goto "http://www.archives.gov.il/search/?q=%D7%A7%D7%9C%D7%95%D7%92%D7%A8&search_type=images&start_period=#{year}&end_period=#{year}"
  puts "waiting for results"
  browser.div(id: 'search-results-results').wait_until_present
  puts "got results"
  # loop over "more results" button
  byebug
  @totals[year] = 0
  @data[year] = []
  while true do 
    a = browser.a(id: 'load-more-resualt') # sic :)
    if a.exist? and a.style != 'display: none;'
      @totals[year] += 40
      puts "loading another batch of up to 40 results (total: #{@totals[year]})"
      a.click
    else
      break
    end
  end
  boxes = browser.divs(:class => 'search-image-box') # grab the search result elements
  boxes.each {|box| grab_item_popup(box, year)}
}
puts "Dumping metadata into kluger.csv"
File.open('kluger.csv','w') {|f|
  @data.keys.each {|year|
    @data[year].each {|item|
      f.print(item.values.to_csv)
    }
  }
}

puts "bye"

