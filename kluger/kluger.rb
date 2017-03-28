# quick script to scrape public domain photos by Zoltan Kluger from the Israeli National Archive, with metadata, for uploading to Commons
# by Asaf Bartov <asaf.bartov@gmail.com>, March 2017
# tested on Ruby 2.2

require 'watir'
require 'byebug'
require 'csv'
require 'getoptlong'
require 'sqlite3'
require 'nokogiri'
require 'open-uri'

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
run with -2 [max_items] to do metadata scraping for all items (or up to max_items)
run with -3 [max_items] to download full images for all items (or up to max_items)
run with -4 to create a Pattypan-compatible upload XML

Each stage will take a while, and will report progress.

When done scraping and downloading, use Pattypan or equivalent batch uploader to upload to Commons

You get the stats for free today! :)
  EOF
  status
  exit
end

def get_db
  db = SQLite3::Database.new "kluger.db"
  db.results_as_hash = true
  return db
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
  db = get_db
  begin
    db.execute('DROP TABLE items;')
  rescue
  end
  db.execute('CREATE TABLE items (id integer primary key autoincrement, item_url varchar(400), download_url varchar(400), thumb_url varchar(400), title varchar(400), description varchar(400), year varchar(20), date_taken varchar(40), events varchar(400), places varchar(400), people varchar(500), fileno varchar(500), status int)')
  puts "done!\nYou are ready to run 'ruby kluger.rb -1' now."
end

def populate
  puts "Opening database"
  db = get_db
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
        db.execute('INSERT INTO items VALUES (NULL, ?, ?, ?, ?, NULL, ?, NULL, NULL, NULL, NULL, NULL, ?)', item[:item_url], item[:download_url], item[:thumb_url], item[:title], item[:year], URLS ) if res.nil? # don't insert duplicates, just in case
        f.print(item.values.to_csv)
      }
    }
  }
  
  puts "POPULATE phase done.  You are ready to run 'ruby kluger.rb -2' now."
end

def status
  db = get_db
  total_count = db.execute("SELECT COUNT(id) FROM items")[0]['COUNT(id)']
  urls_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", URLS)[0]['COUNT(id)']
  metadata_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", METADATA)[0]['COUNT(id)']
  downloaded_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", DOWNLOADED)[0]['COUNT(id)']
  missing_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", MISSING)[0]['COUNT(id)']
  download_error_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", DOWNLOAD_ERROR)[0]['COUNT(id)']
  exported_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", EXPORTED)[0]['COUNT(id)']
  puts "Stats:\n\n#{total_count} total items known.  Of those:\n#{exported_count} exported, #{downloaded_count} downloaded, #{metadata_count} got metadata but not downloaded, #{urls_count} got basic URLs but no full metadata, #{missing_count} missing images at archive, #{download_error_count} download errors"
end

def update_metadata(b, db, id, url)
  b.goto url
  rec = {}
  itemdata = b.div(id: 'item-data')
  itemdata.wait_until_present
  itemdata.div(id: 'show-more-metas').click # show extra metadata, including date
  from = nil
  to = nil
  itemdata.h2s.each {|h2|
    case h2.text
    when 'תאריך התצלום' # date of photo
      rec['date_taken'] = h2.parent.p.text 
    when 'ארועים' # events
      rec['events'] = h2.parent.ul.text
    when 'מקום' # places
      rec['places'] = h2.parent.ul.text
    when 'אישים' # people
      rec['people'] = h2.parent.ul.text
    when 'תיאור המסמך' # description
      rec['description'] = h2.parent.p.text
    when 'שם מקורי עברית' # original name in Hebrew
      rec['description'] = h2.parent.p.text # assuming won't co-exist with description, or that they'd be identical
    when 'מספר תיק לציטוט' # file number in national archive
      rec['fileno'] = h2.parent.p.text
    when 'תקופת החומר עד'
      to = h2.parent.p.text
    when 'תקופת החומר מ'
      from = h2.parent.p.text
    end
  }
  rec['date_taken'] = "בין #{from} ל-#{to}" unless from.nil? or to.nil? or (not rec['date_taken'].nil?) # a little hack for approximate dates when no concrete date is known
  return false if rec.keys.count == 0
  statement_stub = 'UPDATE items SET '
  rec.keys.each{|k|
    st = "#{statement_stub} #{k} = ? WHERE id = ?"
    db.execute(st, rec[k], id) # yeah, lazy to do separate UPDATEs for each value.  Doesn't matter for this one-time scraping.
  }
  db.execute(statement_stub+' status = ? WHERE id = ?', METADATA, id) # mark as done
  return true
end

def scrape(max)
  db = get_db
  urls_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", URLS)[0]['COUNT(id)']
  puts "Scraping full metadata for #{max.nil? ? urls_count : max} out of a total of #{urls_count} URLs without metadata..."
  browser = Watir::Browser.new :firefox
  total_updated = 0
  db.execute("SELECT id, item_url FROM items WHERE status = ?"+(max.nil? ? '' : " LIMIT #{max}"), URLS) do |row|
    total_updated += 1 if update_metadata(browser, db, row['id'], row['item_url'])
  end
  puts "updated #{total_updated} records out of #{urls_count} attempted. You can run kluger.rb -3 now to actually download the full images."
end

def download_image(db, id, url)
  begin
    File.open("full_images/kluger_#{id}.jpg", 'wb') do |fo|
      fo.write open(url).read
    end
    db.execute("UPDATE items SET status = ? WHERE id = ?", DOWNLOADED, id)
  rescue
    db.execute("UPDATE items SET status = ? WHERE id = ?", DOWNLOAD_ERROR, id)
    return false
  end
end

def download(max)
  db = get_db
  metadata_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", METADATA)[0]['COUNT(id)']
  downloaded_count = db.execute("SELECT COUNT(id) FROM items WHERE status = ?", DOWNLOADED)[0]['COUNT(id)']
  todo = max.nil? ? metadata_count : max
  puts "Downloading #{todo} full images out of a total of #{metadata_count} still to be done..."
  total_downloaded = 0
  `mkdir ./full_images > /dev/null` # lazily make sure the directory exists
  db.execute("SELECT id, download_url FROM items WHERE status = ?"+(max.nil? ? '' : " LIMIT #{max}"), METADATA) do |row|
    total_downloaded += 1 if download_image(db, row['id'], row['download_url'])
  end
end

def make_xml
end

# main
puts 'kluger.rb v0.1'
opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--prepare', '-0', GetoptLong::NO_ARGUMENT ],
  [ '--populate', '-1', GetoptLong::NO_ARGUMENT ],
  [ '--scrape', '-2', GetoptLong::OPTIONAL_ARGUMENT],
  [ '--download', '-3', GetoptLong::OPTIONAL_ARGUMENT],
  [ '--make-xml', '-4', GetoptLong::NO_ARGUMENT],
  [ '--status', '-s', GetoptLong::NO_ARGUMENT]
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
      scrape(arg)
      did_something = true
    when '--download'
      download(arg)
      did_something = true
    when '--make-xml'
      make_xml
      did_something = true
  end
}
usage unless did_something

