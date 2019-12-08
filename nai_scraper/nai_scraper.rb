# scrape names of scholars from the National Academy of Science in Israel
require 'watir'

def add_names
  @browser.h3s.each{|h| @names << h.text.sub(/^פרופ' /,'')}
end

def scrape(url)
  p = 1
  @browser.goto url
  add_names
  next_page = @browser.a(id: 'ctl00_content_Pager2_nextPage')
  while next_page.exist?
    p += 1
    puts "clicking to page #{p}"
    next_page.click
    @browser.wait
    add_names
    next_page = @browser.a(id: 'ctl00_content_Pager2_nextPage')
  end
end

# main
@names = []
puts "Launching browser..."
@browser = Watir::Browser.new :chrome, options: {args: ['--no-sandbox', '--headless']}

# scrape past members
puts "Scraping past members..."
scrape('https://www.academy.ac.il/Index2/?nodeId=754')

# scrape current members
puts "Scraping current members..."
scrape('https://www.academy.ac.il/Index2/?nodeId=752')

File.open('nai_scraper_output.txt', 'w'){|f|
  f.truncate(0)
  f.write(@names.join("\n"))
}

puts "Done. Output at nai_scraper_output.txt :)"