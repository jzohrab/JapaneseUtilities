# Wrapper around Classic Jisho.org website.
# Looks up a word and gets its reading and definition.

require 'uri'
require 'net/http'
require 'net/http/responses'

class JishoLookup

  # Returns [word, reading, def'n] tuples that match the supplied
  # word.
  def get_base_rows(word, use_common_only)
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
    end

    # Extract [word, reading, def'n] tuples that match root.
    rows =
      data.
      scan(/<td class="kanji_column">.*?<\/td>.*?<\/td>.*?<\/td>/m).
      map { |row| row.scan(/<td.*?>.*?<\/td>/m) }.
      map do |row|
      row.map { |el| el.gsub(/<.*?>/m, '').strip.gsub(/ +/, ' ') }
    end.select { |a, b, c| a.strip == root.force_encoding("UTF-8").strip }

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
      prons = rows.map { |w, p, m| p }.join(', ')
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

end


# Command-line testing
if __FILE__ == $0
  puts "Command-line lookup"
  j = JishoLookup.new
  w = ARGV[0]
  exit if w.nil?
  puts j.get_rows(w).to_s
  puts j.lookup_entry(w).to_s
  puts j.lookup_word(w).to_s
end
