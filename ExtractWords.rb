#!/usr/bin/ruby
# Reads a given input file and pulls out asterisk-delimited words.
#
# Can be used as follows:
#
# cat some_file_with_asterisked_words.txt | ./ExtractWords.rb | ruby LookupMulti.rb

data = ARGF.read.scan(/\*.*?\*/)
puts data.map { |s| s.gsub(/^\*/, '').gsub(/\*$/, '') }
