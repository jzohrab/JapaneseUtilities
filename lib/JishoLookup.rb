# Wrapper around Classic Jisho.org website.
# Looks up a word and gets its reading and definition.

require 'uri'
require 'net/http'
require 'net/http/responses'

class JishoLookup

  def initialize()
    @debug = false
  end

  attr_accessor :debug

  def print_debug(s)
    puts s.to_s if @debug
  end
  
  # Returns [word, reading, def'n] tuples that match the supplied
  # word.
  def get_base_rows(word, use_common_only)
    print_debug("Search for #{word} (#{use_common_only ? 'common words only' : 'include uncommon'})")
    uri = "http://classic.jisho.org/words"
    params = { "jap" => word, "dict" => "edict" }
    params["common"] = "on" if use_common_only
    uri = URI(uri)
    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)

    # Assume root form is the same as the given
    root = word.dup

    # If a conjugated form is passed in, jisho redirects.
    if (res.is_a?(Net::HTTPRedirection))
      match = res.body.match(/href="(.*?)"/i)
      url = match.captures[0]
      print_debug("Redirecting to #{url}")
      res = Net::HTTP.get_response(URI(url))
    end

    data = res.body.force_encoding("UTF-8") if res.is_a?(Net::HTTPSuccess)
    data ||= ""
    data.gsub!("\t", "")

    # If jisho redirects, the resulting page says "couldn't find that,
    # found this instead."
    matchword = word.dup.force_encoding("UTF-8").strip
    if match = data.match(/\<span class="instead"\>(.*?)\<\/span\>/i)
      matchword = match.captures[0]
      root = matchword.dup
      print_debug("Word root form: #{root}")
    end

    # Sometimes jisho finds de-inflected words, says "search in plain
    # form."
    if match = data.match(/Search for this in plain form:.*?\<a.*?\>(.*?)\<\/a\>/i)
      matchword = match.captures[0]
      root = matchword.dup
      print_debug("Plain root form: #{root}")
    end
    
    # Extract [word, reading, def'n] tuples that match root.
    rows =
      data.
      scan(/<td class="kanji_column">.*?<\/td>.*?<\/td>.*?<\/td>/m).
      map { |row| row.scan(/<td.*?>.*?<\/td>/m) }.
      map do |row|
      row.map { |el| el.gsub(/<.*?>/m, '').strip.gsub(/ +/, ' ') }
    end
    print_debug("Initial matches:\n" + rows.to_s)
    
    # In some cases, jisho doesn't output anything in the "word"
    # column, e.g. for a hiragana-only search string.
    rows.map! { |a, b, c| [(a == '' ? b : a), b, c] }

    # Get words where the kanji field matches the root, or where the
    # original word passed in matches the reading (can happen when
    # hiragana word is sought which also has a kanji spelling).
    rows.select! do |a, b, c|
      rfe = root.force_encoding("UTF-8").strip
      bfe = b.force_encoding("UTF-8").strip
      root_match = [a.strip, bfe].include?(rfe)
      pronounce_match = (word == bfe)
      root_match || pronounce_match
    end

    rows.map! do |a, b, c|
      culled = c.
               split(/\d+/).
               map { |el| el.strip }.
               select { |el| el != "" }.
               map { |el| el.gsub(/^: /, '') }.
               map { |el| el.gsub(/;$/, '') }.
               map { |el| el.gsub(';', ',') }
      [a, b, culled[0..2].join("; ")]
    end
    rows
  end


  # Returns [word, reading, def'n] tuples that match the supplied
  # word.  First searches in common words only, if none are returned,
  # searches in uncommon words.
  def get_rows(word)
    print_debug "Getting rows for #{word}"
    rows = get_base_rows(word, true)
    rows = get_base_rows(word, false) if rows.size == 0
    rows
  end


  # Returns hash for a lookup:
  #
  # { :root => root_form, :pronounce => pron, :meaning => meaning }
  # Note that the root form may not necessarily match the given word.
  def lookup_entry(word)
    rows = get_rows(word)
    root = rows.map { |w, p, m| w }.uniq.join(", ")
    ret = { :root => root, :pronounce => "?", :meaning => "?" }
    if (rows.size != 0)
      prons = rows.map { |w, p, m| p }.uniq.join(', ')
      meanings = rows.map { |w, p, m| m }.uniq.join('; ')
      ret = { :root => root, :pronounce => prons, :meaning => meanings }
    end
    ret
  end

  # Looks up word, returns array of its pronounciations and meanings.
  # Here for backwards-compatibility with existing scripts, should deprecate.
  def lookup_word(word)
    h = self.lookup_entry(word)
    [ h[:pronounce], h[:meaning] ]
  end

  def build_hash(j, e)
    { :japanese => j.gsub(/<.*?>/, "").strip.force_encoding("UTF-8"),
      :english => e.strip }
  end

  # Returns sentences that match the supplied word.
  # Returns array of hashes, [ {:japanese => '...', :english => '...'}, ... ]
  def get_sentences(word)
    print_debug("Get sentences for #{word}")
    uri = "http://classic.jisho.org/sentences"
    params = { "jap" => word }
    uri = URI(uri)
    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)
    data = res.body

    rows = data.
           scan(/<tr.*?class="(even|odd)".*?>(.*?)<\/tr>/m).
           # Scan with two groups returns each group as an array entry: we only
           # want the TR content, and not the "even/odd" class.
           map { |a, b| b }.
           # raw Japanese and English (with spaces, links, etc)
           map { |s| s.scan(/<td.*?>(.*?)<\/td>/) }.
           map { |j, e| build_hash(j[0], e[0]) }
    rows
  end
  
end


# Command-line testing
if __FILE__ == $0
  puts "Command-line lookup"
  j = JishoLookup.new
  j.debug = true
  w = ARGV[0]
  exit if w.nil?

  puts j.lookup_entry(w).to_s
  puts j.get_sentences(w).to_s
end
