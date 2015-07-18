# coding: utf-8
# Builds a fluent-forever style card, with a placeholder for an image.

require_relative 'lib/JishoLookup'

def get_picture_link(r)
  "<a href=\"https://www.google.co.jp/search?noj=1" +
    "&site=imghp&tbm=isch&source=hp&biw=1363&bih=644" +
    "&q=#{r}\">#{r} - 写真必要</a>"
end

raise "Need input and output file" if (ARGV.size != 2)
infile = ARGV[0]
outfile = ARGV[1]
raise "Missing input file" unless File.exist?(infile)

already_done_words = []
if File.exist?(outfile)
  already_done_words = File.read(outfile).
         split("\n").
         map { |s| s.split("\t") }.
         map { |a| a[0].strip }
end
puts "Already output words: #{already_done_words.to_s}"


in_words = File.read(infile).split("\n")
in_words.map! { |c| c.strip }
words = in_words - already_done_words

jl = JishoLookup.new()

line = 0
words.each do |w|
  line += 1
  w.strip!

  puts "#{line} of #{words.size}: #{w}"
  
  e = jl.lookup_entry(w)
  r = e[:root]
  if ((r || '') == '')
    puts "... no match, skipping"
  else
    picture = get_picture_link(r)
    sentences = jl.get_sentences(w).map { |h| h[:japanese] }.join("<br>")
    output = [r, picture, e[:pronounce], sentences, 'y', 'ff'].join("\t")
    File.open(outfile, "a") { |ff| ff.puts output }
  end
end

puts "Done."
