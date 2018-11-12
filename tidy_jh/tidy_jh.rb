#!/usr/bin/env ruby
#
# Tidy up Ukrainian WLM submissions of Jewish heritage photos
#
# an ad-hoc hack by Asaf Bartov <asaf.bartov@gmail.com>
#
# tested on Ruby 2.5

# 1. iterate over all files in WLM 2018
#2. determine whether file is Jewish Heritage, according to https://uk.wikipedia.org/w/index.php?curid=2810696
#3. if not, next
#4. if JH, ensure it has the JH category.
#5. determine whether it has a heritage ID, or 99.  If 99:
#  a. remove quantity category if there
#  b. remove quality category if there
#  c. add obviously ineligible category, if not there

require 'rubygems'
require 'mediawiki_api'
require 'yaml'

CRED = 'wiki_credentials.yml'

# lifted from https://github.com/abartov/wimgs
def category_files(mw, cat)
  ret = []
  last_continue = ''
  done = false
  while not done do
    opts = {cmtitle: "Category:#{cat}", cmlimit: 500, cmtype: 'file', continue: '', cmcontinue: last_continue}
    r = mw.list(:categorymembers, opts)
    ret += r.data.map {|item| item["title"]}
    unless r['continue'] # no need to continue
      done = true
    else
      last_continue = r['continue']['cmcontinue']
    end
    print "#{ret.length} "
  end
  return ret
end

# main logic
def tidy_file(mw, file)
  done_anything = false
  body = mw.get_wikitext(file).body
  summary = 'TidyJH: '
  summary_parts = []
  orig_body = body
  return false unless body =~ /{{Monument Ukraine\|(\d+-\d+-\d+)}}/
  id = $1
  if @recognized.include?(id) or @unrecognized.include?(id)
    @jh += 1
    unless body.index('[[Category:Wiki loves monuments in Ukraine 2018 - Jewish Heritage]]') # ensure it has the JH category
      body += "\n[[Category:Wiki loves monuments in Ukraine 2018 - Jewish Heritage]]"
      summary_parts << 'added [[Category:Wiki loves monuments in Ukraine 2018 - Jewish Heritage]]'
    end
    if id[0..1] == '99' # i.e. unrecognized monument
      if body.index('[[Category:Wiki loves monuments in Ukraine 2018 - Quality]]')
        body.gsub!('[[Category:Wiki loves monuments in Ukraine 2018 - Quality]]','') # remove quality category if there
        summary_parts << 'removed [[Category:Wiki loves monuments in Ukraine 2018 - Quality]]'
      end
      if body.index('[[Category:Wiki loves monuments in Ukraine 2018 - Quantity]]')
        body.gsub!('[[Category:Wiki loves monuments in Ukraine 2018 - Quantity]]','') # remove quantity category if there
        summary_parts << 'removed [[Category:Wiki loves monuments in Ukraine 2018 - Quantity]]'
      end
      unless body.index('[[Category:Obviously ineligible submissions for WLM 2018 in Ukraine]]') #  c. add obviously ineligible category, if not there
        body += "\n[[Category:Obviously ineligible submissions for WLM 2018 in Ukraine]]"
        summary_parts << 'added [[Category:Obviously ineligible submissions for WLM 2018 in Ukraine]]'
      end
    end
    unless body == orig_body # update the file only if necessary
      done_anything = true
      mw.edit({title: file, text: body, summary: summary+summary_parts.join('; '), bot: 'true'}) # an edit conflict would fail the request # TODO: verify!
    end
  end
  return done_anything
end

# main script

# read credentials
cred_hash = ''
begin
  cred_hash = YAML::load(File.open(CRED, 'r').read)
rescue
  puts "#{CRED} not found or not readable!  Terminating."
  exit
end

# setup
puts "logging in."
mw = MediawikiApi::Client.new("https://commons.wikimedia.org/w/api.php")
mw.log_in(cred_hash['user'], cred_hash['password'])

print "reading JH IDs..."
@recognized = File.open('recognized_jh_ids.lst').read.lines.map{|x| x.strip}
@unrecognized = File.open('unrecognized_jh_ids.lst').read.lines.map{|x| x.strip}
puts "done!"
print "getting list of all files in Commons WLM 2018 category..."
catfiles = category_files(mw, 'Images from Wiki Loves Monuments 2018 in Ukraine')
puts "done!"
print "reading already-done list..."
@already_done = File.exist?('already_done.lst') ? File.open('already_done.lst','r').read.lines.map{|x| x.strip} : []
puts "done!"
puts "Tidying up files:"
i = 0
tidied = 0
skipped = 0
@jh = 0
File.open('already_done.lst','a') {|f|
  catfiles.each{|file|
    unless @already_done.include?(file)
      tidied += 1 if tidy_file(mw, file)
      f.puts(file) # record progress for future run
      i += 1
    else
      skipped += 1
    end
    puts "... #{skipped} files skipped, #{i} files reviewed, #{@jh} identified as Jewish heritage, #{tidied} tidied" if i % 20 == 0 and i > 0
    exit if tidied > 50 # throttle, pending bot approval
  }
  puts "done!"
}

exit 0

