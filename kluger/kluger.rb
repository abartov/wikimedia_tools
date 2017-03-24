# quick script to scrape public domain photos by Zoltan Kluger from the Israeli National Archive, with metadata, for uploading to Commons
# by Asaf Bartov <asaf.bartov@gmail.com>, March 2017
# tested on Ruby 2.2

require 'watir'
require 'byebug'
require 'csv'
require 'getoptlong'
require 'sqlite3'
require 'nokogiri'

# status codes
URLS = 1
METADATA = 2
DOWNLOADED = 3
MISSING = 4
DOWNLOAD_ERROR = 5
EXPORTED = 6

def usage
  puts <<-EOF
Scraper for Zoltan Kluger collection at the Israeli National Archive

run with -0 to prepare an empty (Sqlite) database
run with -1 to do initial scrape and create item database
run with -2 to do metadata scraping for all items
run with -3 to download full images
run with -4 to create a Pattypan-compatible upload XML

Each stage will take a while, and will report progress.

When done scraping and downloading, use Pattypan or equivalent batch uploader to upload to Commons
  EOF
  exit
end

def grab_item_popup(box, year)
  img = box.imgs[0]
  alt = img.alt
  thumb_url = img.src
  anchor = box.a
  if anchor.exist?
    anchor.click
    item_url = box.a(:class => 'search-image-read-more').href
    download_url = box.a(:class => 'search-image-icon download').href
    @data[year] << {item_url: item_url, download_url: download_url, thumb_url: thumb_url, title: alt, year: year}
  end
  # dismiss popup
  close = box.span(:class => 'popup-close')
  close.exist?
  close.click
end
def prepare
  print "Preparing empty database kluger.db... "
  db = SQLite3::Database.new "kluger.db"
  db.results_as_hash = true
  begin
    db.execute('DROP TABLE items;')
  rescue
  end
  db.execute('CREATE TABLE items (id integer primary key autoincrement, item_url varchar(400), download_url varchar(400), thumb_url varchar(400), title varchar(400), description varchar(400), year varchar(20), date_taken varchar(40), places varchar(200), people varchar(500), status int)')
  puts "done!\nYou are ready to run 'ruby kluger.rb -1' now."
end

def populate
  puts "Opening database"
  db = SQLite3::Database.new "kluger.db"
  db.results_as_hash = true
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
  puts "Dumping metadata into kluger.csv and populating kluger.db"
  File.open('kluger.csv','w') {|f|
    @data.keys.each {|year|
      @data[year].each {|item|
        res = nil
        begin
          res = db.execute("SELECT id FROM items WHERE item_url = ?", item[:item_url])[0] # check whether already exists
        rescue
        end
        db.execute('INSERT INTO items VALUES (NULL, ?, ?, ?, ?, NULL, ?, NULL, NULL, NULL, ?)', item[:item_url], item[:download_url], item[:thumb_url], item[:title], item[:year], URLS ) if res.nil? # don't insert duplicates, just in case
        f.print(item.values.to_csv)
      }
    }
  }
  
  puts "POPULATE phase done.  You are ready to run 'ruby kluger.rb -2' now."
end

# main
puts 'kluger.rb v0.1'
opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--prepare', '-0', GetoptLong::NO_ARGUMENT ],
  [ '--populate', '-1', GetoptLong::NO_ARGUMENT ],
  [ '--scrape', '-2', GetoptLong::NO_ARGUMENT],
  [ '--download', '-3', GetoptLong::NO_ARGUMENT],
  [ '--make-xml', '-4', GetoptLong::NO_ARGUMENT]
)
did_something = false
opts.each {|opt, arg|
  case opt
    when '--help'
      usage
      did_something = true
    when '--prepare'
      prepare
      did_something = true
    when '--populate'
      populate
      did_something = true
    when '--scrape'
      scrape
      did_something = true
    when '--download'
      download
      did_something = true
    when '--make-xml'
      make_xml
      did_something = true
  end
}
usage unless did_something

