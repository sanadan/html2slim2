require_relative 'html2slim2/version'
require_relative 'html2slim2/converter'

module HTML2Slim2
  def self.convert!(input, format = :html)
    if format.to_s == "html"
      HTMLConverter.new(input)
    else
      ERBConverter.new(input)
    end
  end
end
