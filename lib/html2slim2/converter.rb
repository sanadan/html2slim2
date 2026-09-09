module HTML2Slim2
  MULTILINE_ATTR_MARKER = 'html2slim2-multiline'
end

require_relative 'nokogiri_monkey_patches'

module HTML2Slim2
  class Converter
    OPENING_TAG_RE = /<([A-Za-z][A-Za-z0-9:-]*)((?:[^>"']|"[^"]*"|'[^']*')*)(\/?)>/m

    def initialize(html)
      html = mark_multiline_opening_tags(html)
      nokogiri = html[..1] == '<!' ? Nokogiri.parse(html) : Nokogiri::HTML.fragment(html)
      @slim = nokogiri.to_slim
    end

    def to_s
      @slim
    end

    private

    def mark_multiline_opening_tags(html)
      html.gsub(OPENING_TAG_RE) do |match|
        attrs = Regexp.last_match[2]
        next match unless attrs.include?("\n")

        name = Regexp.last_match[1]
        slash = Regexp.last_match[3]
        %(<#{name}#{attrs} #{MULTILINE_ATTR_MARKER}="1"#{slash}>)
      end
    end
  end

  class HTMLConverter < Converter
    def initialize(file)
      html = file.read
      super(html)
    end
  end

  class ERBConverter < Converter
    def initialize(file)
      erb = file.read

      erb.gsub!(/<%(.+?)\s*\{\s*(\|.+?\|)?\s*%>/) { %(<%#{$1} do #{$2}%>) }
      # case, if, for, unless, until, while, and blocks...
      erb.gsub!(/<%(-\s+)?((\s*(case|if|for|unless|until|while) .+?)|.+?do\s*(\|.+?\|)?\s*)-?%>/) do
        %(<ruby code="#{escape($2)}">)
      end
      # else
      erb.gsub!(/<%-?\s*else\s*-?%>/, %(</ruby><ruby code="else">))
      # elsif
      erb.gsub!(/<%-?\s*(elsif .+?)\s*-?%>/) { %(</ruby><ruby code="#{escape($1)}">) }
      # when
      erb.gsub!(/<%-?\s*(when .+?)\s*-?%>/) { %(</ruby><ruby code="#{escape($1)}">) }
      erb.gsub!(/<%\s*(end|}|end\s+-)\s*%>/, %(</ruby>))
      erb.gsub!(/<%-?\n?(.+?)\s*-?%>/m) { %(<ruby code="#{escape($1)}"></ruby>) }

      super(erb)
    end

    private

    def escape(str)
      str.gsub!('&', '&amp;')
      str.gsub!('"', '&quot;')
      str.gsub!("\n", '\n')
      str.gsub!('<', '&lt;')
      str
    end
  end
end
