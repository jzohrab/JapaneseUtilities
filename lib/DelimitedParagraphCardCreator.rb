# Creates Anki card data from a paragraph containing delimited words,
# with the sentences of the paragraph being the example sentences for
# the word (no English translation, it's assumed that the context is
# sufficient).
class DelimitedParagraphCardCreator

  def get_words(sentence)
    words = sentence.scan(/\*.*?\*/).uniq
    words.map! { |s| s.gsub(/^\*/, '').gsub(/\*$/, '') }
    words
  end

  def get_dictionary(para, lkp_src)
    dict = {}
    get_words(para).each do |w|
      dict[w] = lkp_src.lookup(w)
    end
    dict
  end
  
  # Output root, pronounce, meaning for given words.
  def create_notes(data, words)
    outdata = {}
    words.each do |w|
      outdata[w] = data[w]
    end
    return [] if outdata.keys.size == 0
    outdata.values.map { |o| [ o[:root], o[:pronounce], o[:mean] ] }
  end
  
  # Given a sentence, extracts array of data for one or more cards.
  def create_cards_for_sentence(s, dict)
    words = get_words(s)
    output = words.map do |w|
      remaining_words = words - [w]
      d = dict[w]
      raise "missing dictionary entry for word #{w}" if d.nil?
      {
        :word => w,
        :root => d[:root],
        :pronounce => d[:pronounce],
        :mean => d[:mean],
        :sentence => s.gsub('*', ''),
        :notes => create_notes(dict, remaining_words)
      }
    end
    output
  end

  # Given a paragraph, extracts array of data for one or more cards.
  def extract_card_data(para, lkp_src)
    dict = get_dictionary(para, lkp_src)
    data = []
    self.extract_sentences(para).each do |s|
      data << self.create_cards_for_sentence(s, dict)
    end
    data.flatten
  end
  
  # Given a paragraph, extract the sentences.
  # Para given as text, separates at "\n" or at fullstop.
  def extract_sentences(p)
    fullstop = "\u3002"
    p.split(/[#{fullstop}\n]/).map { |s| "#{s}#{fullstop}" }.delete_if { |s| s == fullstop }
  end

  def format_note(word, pronounciation, meaning)
    return "#{word}: #{meaning}" if (word == pronounciation)
    return "#{word}[#{pronounciation}]: #{meaning}"
  end
  
  # Given a paragraph, splits into sentences, and then generates card data for each.
  def generate_cards(para, lkp_src, tag = nil)
    data = extract_card_data(para, lkp_src)
    data.map do |d|
      n = d[:notes].map { |a, b, c| format_note(a, b, c) }
      highlighted = d[:sentence].dup.gsub(d[:word], "<font color=\"#ff0000\">#{d[:word]}</font>")
      card = [d[:root], d[:pronounce], d[:mean], highlighted, n.join("<br>")]
      card << tag if tag
      card.join("\t")
    end
  end

end
