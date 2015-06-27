# Script to lookup words and pronunciations for multiple unknown
# words.
#
# Given a single-field list of words (kanji only), this script calls
# out to jisho.org and gets the pronounciation and definition, and
# prints it out to console.
#
# This script can be used to continually append to an output file, eg:
#   ruby this_script.rb < input.txt >> output.txt
# The above can be a useful operation when going through existng
# cards, and picking out meanings not already clear.


require_relative 'lib/JishoLookup'

def print_data(data)
  data.each do |d|
    puts d.join("\t")
  end
end

raw = []
ARGF.each_with_index do |line, idx|
  raw << line
end
data = raw.map { |x| x.strip }.select { |el| el !~ /^#/ }

quit_loc = data.map { |el| el.downcase }.find_index("quit")
data = data[0..(quit_loc - 1)] unless quit_loc.nil?

jl = JishoLookup.new
data.map! do |w|
  r = jl.lookup_word(w)
  [w, r[0], r[1]]
end

print_data( data.select { |w, p, m| p != "?" } )

baddata = data.select { |w, p, m| p == "?" }
if (baddata.size > 0)
  2.times { puts "#" }
  puts "# Please check the following:"
  print_data( baddata.map { |w, p, m| [w, w, m] } )
end
