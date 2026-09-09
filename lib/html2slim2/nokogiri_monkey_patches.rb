require 'nokogiri'

class Nokogiri::XML::Text
  def to_slim(lvl = 0)
    str = escape(content)
    return nil if str.strip.empty?

    ('  ' * lvl) + %(| #{str.gsub(/\s+/, ' ')})
  end

  private

  def escape(str)
    str.gsub!('&', '&amp;')
    str.gsub!('©', '&copy;')
    str.gsub!("\u00A0", '&nbsp;')
    str.gsub!('»', '&raquo;')
    str.gsub!('<', '&lt;')
    str.gsub!('>', '&gt;')
    str
  end
end

class Nokogiri::XML::DTD
  def to_slim(_lvl = 0)
    if to_xml.include?('xml')
      to_xml.include?('iso-8859-1') ? 'doctype xml ISO-88591' : 'doctype xml'
    elsif to_xml.include?('XHTML') || to_xml.include?('HTML 4.01')
      available_versions = Regexp.union ['Basic', '1.1', 'strict', 'Frameset', 'Mobile', 'Transitional']
      version = to_xml.match(available_versions).to_s.downcase
      "doctype #{version}"
    else
      'doctype html'
    end
  end
end

class Nokogiri::XML::Element
  BLANK_RE = /\A[[:space:]]*\z/.freeze

  def slim(lvl = 0)
    indent = '  ' * lvl

    return indent + slim_ruby_code(indent) if ruby?

    r = indent
    r += name unless skip_tag_name?
    r += slim_id
    r += slim_class
    r += slim_attributes(indent)
    r
  end

  def to_slim(lvl = 0)
    if children.any?
      %(#{slim(lvl)}\n#{children.filter_map { |c| c.to_slim(lvl + 1) }.join("\n")})
    else
      slim(lvl)
    end
  end

  private

  def slim_ruby_code(indent)
    (code.strip[0] == '=' ? '' : '- ') + code.strip.gsub('\\n', "\n#{indent}- ")
  end

  def code
    attributes['code'].to_s
  end

  def skip_tag_name?
    div? && (has_id? || has_class?)
  end

  def slim_id
    has_id? ? "##{self['id']}" : ''
  end

  def slim_class
    has_class? ? ".#{self['class'].to_s.strip.split(/\s+/).join('.')}" : ''
  end

  def slim_attributes(indent = '')
    multiline = has_attribute?(HTML2Slim2::MULTILINE_ATTR_MARKER)
    remove_attribute(HTML2Slim2::MULTILINE_ATTR_MARKER)
    remove_attribute('class')
    remove_attribute('id')
    return '' unless has_attributes?

    if multiline && multiline_attribute_output?
      slim_multiline_attributes(indent)
    else
      "[#{attributes_as_html.to_s.strip}]"
    end
  end

  def multiline_attribute_output?
    attrs = attributes.to_hash
    attrs.size > 1 || attrs.values.any? { |value| value.to_s.include?("\n") }
  end

  def slim_multiline_attributes(indent)
    parts = attributes.map do |attr_name, attr_val|
      attr_val ? "#{attr_name}=#{html_quote attr_val.to_s}" : attr_name.to_s
    end
    return "[#{parts.first}]" if parts.size <= 1

    inner_indent = "#{indent}  "
    "[\n#{parts.map { |part| "#{inner_indent}#{part}" }.join("\n")}\n#{indent}]"
  end

  def has_attributes? # rubocop:disable Naming/PredicatePrefix
    attributes.to_hash.any?
  end

  def has_id? # rubocop:disable Naming/PredicatePrefix
    has_attribute?('id') && !(BLANK_RE === self['id'])
  end

  def has_class? # rubocop:disable Naming/PredicatePrefix
    has_attribute?('class') && !(BLANK_RE === self['class'])
  end

  def ruby?
    name == 'ruby'
  end

  def div?
    name == 'div'
  end

  def html_quote(str)
    "\"#{str.gsub('"', '\\"')}\""
  end

  def attributes_as_html
    attributes.map do |attr_name, attr_val|
      " #{attr_name}" + (attr_val ? "=#{html_quote attr_val.to_s}" : '')
    end.join
  end
end

class Nokogiri::XML::DocumentFragment
  def to_slim
    if children.any?
      children.filter_map(&:to_slim).join("\n")
    else
      ''
    end
  end
end

class Nokogiri::XML::Document
  def to_slim
    if children.any?
      children.filter_map(&:to_slim).join("\n")
    else
      ''
    end
  end
end

class Nokogiri::XML::Comment
  def to_slim(lvl = 0)
    r = '  ' * lvl

    # Render as a Slim comment, multiline if necessary
    str = content.strip
    return nil if str.empty?

    if str.include?("\n")
      "#{r}/\n#{r}  " + str.gsub("\n", "\n#{r}  ")
    else
      "#{r}/ #{str}"
    end
  end
end
