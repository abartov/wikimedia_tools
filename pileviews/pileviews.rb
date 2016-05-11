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
require './pileviewslib.rb'

VERSION = "0.1 2016-05-10"

def usage 
  puts <<EOF
pileviews - generate a CSV with pageview data from a given PagePile ID, version #{VERSION}

Usage:

$ ruby pileviews.rb <PagePile ID>

For example:

$ ruby pileviews.rb 3036

The tool will create (and overwrite!) a file named "pagepile_<id>.csv" in the current directory, 
where <id> is the provided PagePile ID.

Report bugs to Asaf Bartov, asaf.bartov@gmail.com
EOF
  exit
end

usage if ARGV[0].nil? or ARGV[0].empty?

puts "pileviews - version #{VERSION}\n"
print "Creating pagepile_#{ARGV[0]}.csv... "
pileviews(ARGV[0])
puts "done!"

