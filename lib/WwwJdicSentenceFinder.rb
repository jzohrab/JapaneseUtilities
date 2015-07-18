require 'uri'
require 'net/http'
require 'net/http/responses'


# Calls WWWJDIC backdoor, gets example sentences for word.
# Does raw html parsing.
class WwwJdicSentenceFinder

  # Available sources and mirrors
  SOURCES = {
    'm' => "http://www.csse.monash.edu.au/~jwb/cgi-bin/wwwjdic.cgi",
    'e' => "http://www.edrdg.org/cgi-bin/wwwjdic/wwwjdic"
  }

  # src is the key, lookup full URL in SOURCES hash.
  def initialize(src = 'm')
    @src = src
  end

  # Returns array of 10 sentences
  # [ { :japanese => '...', :english => '...' } ]
  def get_sentences(word)
    url= "#{WwwJdicSentenceFinder::SOURCES[@src]}"
    uri = URI(url)

    params = { "1ZEU#{word}" => 1 }
    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)
    ret = res.body.force_encoding("UTF-8") if res.is_a?(Net::HTTPSuccess)

    data = ret.gsub(/.*\<pre\>/m, '').gsub(/\<\/pre\>.*/m, '')
    sentences = data.split("\n").select { |s| s =~ /^A/ }
    sentences.map! do |s|
      temp = s.gsub( /^A:/, '').
        gsub(/#ID=.*$/, '').
        strip.
        split("\t")
      { :japanese => temp[0], :english => temp[1] }
    end
    sentences
  end
end



# Command-line testing
if __FILE__ == $0
  puts "Command-line lookup"
  j = WwwJdicSentenceFinder.new()
  # j.debug = true
  w = ARGV[0]
  exit if w.nil?

  puts j.get_sentences(w).to_s
end
