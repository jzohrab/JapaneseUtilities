# coding: utf-8

require 'test/unit'
require_relative '../lib/DelimitedParagraphCardCreator'


class DummySource
  def initialize()
    @hsh = {}
  end

  # Required API method
  def lookup(w)
    return @hsh[w] if @hsh.has_key?(w)
    make_entry(w, "?", "?")
  end

  # Populate the lookup hash
  def add_word_default(w)
    add_word(w, "#{w}r", "#{w}p", "#{w}m")
    
  end
  def add_word(w, r, p, m)
    @hsh[w] = make_entry(r, p, m)
  end
  def make_entry(r, p, m)
    { :root => r, :pronounce => p, :mean => m }
  end
end


class TestDelimitedParagraphCardCreator < Test::Unit::TestCase

  def setup()
    @dummysource = DummySource.new
    @creator = DelimitedParagraphCardCreator.new()
  end

  # Convert data structs to strings for testing
  def card_to_s(data)
    data.map do |d|
      s = d[:sentence].gsub("。", "")
      n = d[:notes].map { |a| a.join("-") }.join(", ")
      "#{d[:root]}; #{d[:pronounce]}; #{d[:mean]}; #{s}; notes: #{n}"
    end.sort
  end
  
  def check_output(s, expected, msg)
    actual = card_to_s(@creator.extract_card_data(s, @dummysource))
    assert_equal(expected.sort, actual, msg)
  end
  
  def test_sentences()
    @dummysource.add_word_default("A")
    @dummysource.add_word_default("B")
    @dummysource.add_word_default("C")
    @dummysource.add_word("F", "Fdiff_r", "Fdiff_p", "Fdiff_m")
    
    check_output("", [], "edge case")
    check_output("hello", [], "no delimiters")
    check_output("*A*B", [ "Ar; Ap; Am; AB; notes: " ], "simple case, single word")
    check_output("*A**B*", [ "Ar; Ap; Am; AB; notes: Br-Bp-Bm", "Br; Bp; Bm; AB; notes: Ar-Ap-Am" ], "two words")
    check_output("*A**B**C*", [ "Ar; Ap; Am; ABC; notes: Br-Bp-Bm, Cr-Cp-Cm", "Br; Bp; Bm; ABC; notes: Ar-Ap-Am, Cr-Cp-Cm", "Cr; Cp; Cm; ABC; notes: Ar-Ap-Am, Br-Bp-Bm" ], "three words")
    check_output("*X*", [ "X; ?; ?; X; notes: " ], "missing word")
    check_output("*A**X*", [ "Ar; Ap; Am; AX; notes: X-?-?", "X; ?; ?; AX; notes: Ar-Ap-Am" ], "have word, missing word")

    check_output("*F*B", [ "Fdiff_r; Fdiff_p; Fdiff_m; FB; notes: " ], "single word, different form")
    check_output("*F**B*", [ "Fdiff_r; Fdiff_p; Fdiff_m; FB; notes: Br-Bp-Bm", "Br; Bp; Bm; FB; notes: Fdiff_r-Fdiff_p-Fdiff_m" ], "2 words, different form")

    check_output("*F**B", [ "Fdiff_r; Fdiff_p; Fdiff_m; FB; notes: " ], "B not closed out")
  end

  def test_extract()
    assert_equal(["何。","本。"], @creator.extract_sentences("何。本。"), "split")
    assert_equal(["何,本。"], @creator.extract_sentences("何,本"), "as-is, fullstop added (assumes full sentence)")
    assert_equal(["何。","本。"], @creator.extract_sentences("何\n本"), "split at CRLF")
    assert_equal(["何。","本。"], @creator.extract_sentences("何。\n本。"), "split, no redundant split")
  end


  def test_get_dictionary()
    %w(A B C).each { |w| @dummysource.add_word_default(w) }
    para = "*A* here.\nThis is *C*."
    dict = @creator.get_dictionary(para, @dummysource)
    expected = {
      "A" => { :root => "Ar", :pronounce => "Ap", :mean => "Am" },
      "C" => { :root => "Cr", :pronounce => "Cp", :mean => "Cm" }
    }
    assert_equal(dict.to_s, expected.to_s)
  end


  def test_card_data_from_delimited_paras()
    @dummysource.add_word("犬", "犬", "いぬ", "dog")
    @dummysource.add_word("大きい", "大きい", "おおきい", "big")
    @dummysource.add_word("猫", "猫", "ねこ", "cat")
    @dummysource.add_word("走っている", "走る", "はしる", "To run")

    para = "*猫*が*走っている*。

これは*本*です。"
    actual = @creator.generate_cards(para, @dummysource)

    expected = [
      "猫	ねこ	cat	<font color=\"#ff0000\">猫</font>が走っている。	走る[はしる]: To run",
      "走る	はしる	To run	猫が<font color=\"#ff0000\">走っている</font>。	猫[ねこ]: cat",
      "本	?	?	これは<font color=\"#ff0000\">本</font>です。	"
    ]
    assert_equal(actual, expected)

    taggedexpected = expected.map { |s| "#{s}	some_tag" }
    taggedactual = @creator.generate_cards(para, @dummysource, "some_tag")
    assert_equal(taggedactual, taggedexpected, "added a tag")
  end
  
end

