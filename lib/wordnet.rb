module Wordnet

  POINTER_SYMBOLS = { "!"  => "Antonym",
                      "@"  => "Hypernym",
                      "@i" => "Instance Hypernym",
                      "~"  => "Hyponym",
                      "~i" => "Instance Hyponym",
                      "#m" => "Member holonym",
                      "#s" => "Substance holonym",
                      "#p" => "Part holonym",
                      "%m" => "Member meronym",
                      "%s" => "Substance meronym",
                      "%p" => "Part meronym",
                      "="  => "Attribute",
                      "+"  => "Derivationally related form",
                      "*"  => "Entailment",
                      ">"  => "Cause",
                      "^"  => "Also see",
                      "$"  => "Verb Group",
                      "+"  => "Derivationally related form",
                      "&"  => "Similar to",
                      "<"  => "Participle of verb",
                      "\\" => "Pertainym (pertains to noun) for adjectives, Derived from adjective for adverbs",
                      ";c" => "Domain of synset - TOPIC",
                      "-c" => "Member of this domain - TOPIC",
                      ";r" => "Domain of synset - REGION",
                      "-r" => "Member of this domain - REGION",
                      ";u" => "Domain of synset - USAGE",
                      "-u" => "Member of this domain - USAGE" }

  class Entry

    attr_reader :id, :part_of_speech, :words, :pointers, :gloss

    def initialize id, part_of_speech, words, pointers, gloss
      @id, @part_of_speech, @words, @pointers, @gloss = id, part_of_speech, words, pointers, gloss
    end

    def inspect
      "#<Wordnet::Entry::#{@id}[#{@part_of_speech}] @words=#{@words.inspect}>"
    end

    # returns the list of hypernym entries
    def hypernyms
      ids = @pointers.select {|symbol, *_| symbol == "@" }.map {|_, offset, *_| offset.to_i }
      ids.map {|id| Wordnet[id, part_of_speech] }
    end

    # returns a tree of hypernyms
    def hypernym_ancestors
      root = Tree::TreeNode.new(inspect, self)

      hypernyms.each do |word|
        (word_ancestors = word.hypernym_ancestors)
        root << word_ancestors if word_ancestors
      end

      root
    end

    def hypernym_distance_from other
      my_distances = hypernym_ancestor_distances
      other_distances = other.hypernym_ancestor_distances
      common_ids = my_distances.keys & other_distances.keys

      common_ids.map {|id| my_distances[id] + other_distances[id] }.min
    end

    def hypernym_ancestor_distances
      distances = {id => 0}

      hypernyms.each do |child|
        distances[child.id] = 1

        child.hypernym_ancestor_distances.each do |id, distance|
          distances[id] = [distances[id], distance + 1].compact.min
        end
      end

      distances
    end

    def height
      hypernym_ancestors.node_height
    end

    def <=> other
      height <=> other.height
    end

  end

  module ClassMethods

    # not sure we want to keep this here after testing
    attr_reader :data, :index

    @loaded = false
    @data = {}
    @index = {}

    PARTS_OF_SPEECH = [:noun, :verb, :adj, :adv]
    DATA_PATH = File.join File.dirname(__FILE__), "data"

    def included _
      @data = Hash.new
      @index = Hash.new

      PARTS_OF_SPEECH.each do |part_of_speech|
        pos_data = {}
        pos_index = {}
        filename = File.join DATA_PATH, "data.#{part_of_speech}"

        File.readlines(filename).each do |line|
          next if line =~ /^  /

          entry = parse_entry line, part_of_speech

          pos_data[id] = entry
          words.each {|word, pointer| pos_index[word.downcase] = entry }
        end

        @data[part_of_speech] = pos_data
        @index[part_of_speech] = pos_index
      end

      @loaded = true
    end

    def loaded?
      !! @loaded
    end

    # return all results across all parts of speech
    def search word
      PARTS_OF_SPEECH.map {|part_of_speech| @index[part_of_speech][word.downcase] }.compact
    end

    # return first result across all parts of speech
    def find word
      search(word).first
    end

    def [] id, part_of_speech
      return unless @loaded and @data
      return unless (pos_data = @data[part_of_speech.to_sym])

      pos_data[id.to_i]
    end

    private

    def parse_entry line, part_of_speech
      data, gloss = line.split /\|/, 2
      id_string, _, _, word_count, *words_and_pointers = data.split /\s/
      id = id_string.to_i

      # parse the words
      words = Hash.new

      word_count.to_i.times do
        word, pointer = words_and_pointers.shift(2)
        word.gsub! /_/, " "

        words[word] = pointer
      end

      # parse the pointers
      pointer_count = words_and_pointers.shift
      pointers = Array.new

      pointer_count.to_i.times do
        symbol, offset, type, source_or_target = words_and_pointers.shift(4)
        pointers << [symbol, offset, type, source_or_target]
      end

      Entry.new id, part_of_speech, words, pointers, gloss
    end

  end
  extend ClassMethods

end
