# Script to create MCD cards from a delimited story.
#
# Given a file containing a story with desired cloze words delimited
# with "*", outputs the marked-up result and extra content so that the
# word reading can be practiced. Prints it out to console.
#


require_relative 'lib/JishoLookup'

# Test lookup during dev
class TestLookup
  def lookup_word(word)
    return [ "pron_#{word}", "mean_#{word}" ]
  end
end

# dict is a hash: word => [pronounciation, meaning]
def generate_cloze_card(content, dict)
  # Add furigana cloze.  Will fix card numbering after.
  output = content.clone
  dict.keys.each do |w|
    p = dict[w][0]
    m = dict[w][1]
    output.gsub!("*#{w}*", " #{w}[!{{c_NUMBER_::#{p}: #{m}}}]")
  end

  # Order the furigana cards:
  # Replace _NUMBER_ token with numbers.
  i = 1
  while (output.include?("{{c_NUMBER_::"))
    output.sub!("{{c_NUMBER_::", "{{c#{i}::")
    i += 1
  end

  output
end

# Print vocab
def print_data(data)
  data.each do |d|
    puts d.join("\t")
  end
end

content = ARGF.read

words = content.scan(/\*.*?\*/).uniq
words.map! { |s| s.gsub(/^\*/, '').gsub(/\*$/, '') }


# Get each entry, get its pronounciations and meanings
# lk = TestLookup.new  # During dev.
lk = JishoLookup.new
dict = {}
words.each do |w|
  dict[w] = lk.lookup_word(w)
end


output = generate_cloze_card(content, dict)
puts output
puts
puts "-"*20
puts

# Output the vocab
data = words.map { |w| [ w, dict[w][0], dict[w][1] ] }
print_data( data.select { |w, p, m| p != "?" } )
baddata = data.select { |w, p, m| p == "?" }
if (baddata.size > 0)
  2.times { puts "#" }
  puts "# Missing words, please check the following in the generated cloze:"
  print_data( baddata.map { |w, p, m| [w, w, m] } )
end
