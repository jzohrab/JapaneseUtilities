# Given a file containing a story with words delimited with "*",
# breaks the file's sentences apart and gens output for cards that use
# the sentence as an example.
#
# run with "--help" for options
# - output a dictionary for further editing if desired
# - specify a dictionary file to use as word lookup source
#
# Suggested usage:
# 1. Run and specify "-d", output the dictionary to a file
# 2. Edit that dictionary file, looking up missing words, shortening definitions, etc
# 3. Run and specify "-f", using the edited dictionary file

require_relative 'lib/JishoLookup'
require_relative 'lib/DelimitedParagraphCardCreator'
require 'optparse'
require 'yaml'


######################################
# Lookup sources

class JishoLookupAdaptor
  def initialize()
    @jl = JishoLookup.new
  end

  def lookup(w)
    d = @jl.lookup_entry(w)
    d[:mean] = d[:meaning]
    d.delete(:meaning)
    d
  end
end

# Lookup words from a supplied file.  This assumes that the file has the
# appropriate fields.
class FileLookup
  def initialize(filepath)
    @data = YAML.load(File.read(filepath))
  end
  def lookup(w)
    @data[w]
  end
end

######################################
# Options

# Return a hash describing the options.
def parse_args(args)
  options = {
    :outputdict => false,
  }

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} <input filepath> [options]"

    opts.separator ""
    opts.separator "Data options:"
    opts.on("-t T", String, "Tag") do |t|
      options[:tag] = t
    end
    opts.on("-f F", String, "Source file for dictionary, instead of Jisho") do |f|
      options[:lookupfile] = f
    end

    opts.separator ""
    opts.separator "Output:"
    opts.on("-d", "--dictionary", "Dump dictionary to console only") do |c|
      options[:dictionary] = c
    end

    opts.separator ""
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end

  opt_parser.parse!(args)
  options
end

################################
# Main

options = parse_args(ARGV)

if (ARGV.size != 1)
  puts "Missing input file path."
  exit 1
end
input = ARGV[0]
if (!File.exist?(input))
  puts "Invalid/missing file name"
  exit 1
end
para = File.read(input)

c = DelimitedParagraphCardCreator.new()
lkp = JishoLookupAdaptor.new()

if options[:lookupfile]
  lkp = FileLookup.new(options[:lookupfile])
end

if options[:dictionary]
  dict = c.get_dictionary(para, lkp)
  puts dict.to_yaml
else
  settings = {
      :preword => "<font color=\"#ff0000\">",
      :postword => "</font>",
      :tag => options[:tag]
    }

  data = c.generate_cards(para, lkp, settings)
  puts data
end
