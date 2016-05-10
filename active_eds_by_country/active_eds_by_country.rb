#!/bin/ruby

require 'csv'

# constants
BUCKET_SIZE = 10
ALL = 1
ACTIVE = 2
VERY_ACTIVE = 3

def which_col(col)
  str = @eds[0][col]
  return ALL if str =~ /all/
  return ACTIVE if str =~ /5\+/
  return VERY_ACTIVE if str =~ /100\+/
  return nil
end
def b(num)
  return num.to_s unless @bucket
  bucketed_num = num - num % BUCKET_SIZE
  return "[#{bucketed_num}-#{bucketed_num + BUCKET_SIZE}]"
end 
def make_report
  repname = "report_on_#{@fname}#{@bucket ? '_bucketed' : ''}.txt"
  puts "Outputting #{repname}"
  File.open(repname, 'w') {|f|
    f.puts "Report on #{@bucket ? 'bucketed ': ''}active editor counts as average between #{@eds[-30][0]} and #{@eds[-1][0]} from file #{@fname}\n"
    f.puts "==Countries by Alphabet=="

    format = "%-40s\t%15s\t%15s\n"
    @active.keys.sort.each {|k| f.printf format, k, @active[k].nil? ? 0 : b(@active[k]), @very_active[k].nil? ? 0 : b(@very_active[k])}
    f.puts "\n==Countries by Active Editor count=="
    sorted_by_active = @active.sort_by {|k,v| v}
    sorted_by_active.reverse.each {|k| f.printf format, k[0], k[1].nil? ? 0 : b(k[1]), @very_active[k[0]].nil? ? 0 : b(@very_active[k[0]])}
  }
end
def make_wiki_report
  repname = "report_on_#{@fname}_bucketed.wiki"
  puts "Outputting wikified report at #{repname}"
  File.open(repname, 'w') {|f|
    f.puts "Report on bucketed active editor counts as average between #{@eds[-30][0]} and #{@eds[-1][0]} from file #{@fname}\n"
    f.puts '==Countries by Alphabet=='
    f.puts "{| class=\"wikitable sortable\"\n|-\n! Country !! Active (5+/month) !! Very active (100+/month)"
    @active.keys.sort.each {|k| f.puts "|-\n| #{k} || #{@active[k].nil? ? 0 : b(@active[k])} || #{@very_active[k].nil? ? 0 : b(@very_active[k])}"}
    f.puts '|}'
    f.puts "\n==Countries by Active Editor count=="
    f.puts "{| class=\"wikitable sortable\"\n|-\n! Country !! Active (5+/month) !! Very active (100+/month)"
    sorted_by_active = @active.sort_by {|k,v| v}
    sorted_by_active.reverse.each {|k| f.puts "|-\n| #{k[0]} || #{k[1].nil? ? 0 : b(k[1])} || #{@very_active[k[0]].nil? ? 0 : b(@very_active[k[0]])}" }
    f.puts '|}'
  }
end
def make_bucketed_csv
  csvname = "report_on_#{@fname}_bucketed.csv"
  puts "Outputting *bucketed* CSV at #{csvname}"
  File.open(csvname, 'w') {|f|
    puts "Country, Active (5+/month), Very active (100+/month)"
    @active.keys.sort.each {|k| f.puts "#{k},#{@active[k].nil? ? 0 : b(@active[k])},#{@very_active[k].nil? ? 0 : b(@very_active[k])}"}
  }
end
def usage
  puts "run this script with the name of a CSV file as an argument, to produce two reports (bucketed and unbucketed)\n\nFor example:\n\n  ruby active_eds_by_country.rb en_all.csv\n\nObtain those CSV files from https://stats.wikimedia.org/geowiki-private/"
  exit 0
end
usage if ARGV.empty?

filename = ARGV[0]
print "Reading #{filename}... "
@eds = CSV.read(filename)
print "done!\nCalculating average editor counts... "
# first column is date, then each country has _up to_ three columns 100+, 5+, 1+, but they'll be missing if no data!
lastcol = @eds[0].size - 1
col = 0
@active = {}
@very_active = {}
# calculate last 30-day averages for each country and category
while col < lastcol do
  col += 1
  which = which_col(col)
  next if which == ALL
  country = @eds[0][col][0..@eds[0][col].index('(')-1]
  country = 'Curaçao' if country =~ /Cura.ao/ # manual fix for Curaçao
  total = 0
  for i in 1..30 do
    val = (@eds[-i][col].to_i or 0)
    total += val
  end
  if which == ACTIVE
    @active[country] = total / 30
  else
    @very_active[country] = total / 30
  end
end
puts "done!"
# output
@fname = File.split(filename)[-1]
@bucket = false
make_report # without bucketing
@bucket = true
make_report # then bucketed
make_wiki_report # make a wiki-ready version of the bucketed numbers
make_bucketed_csv # make a bucketed version of the CSV, too
puts "done!"
