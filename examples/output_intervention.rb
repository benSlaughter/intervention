require 'pry'
require 'intervention'

module Test
  def self.request connection
    p connection.parser.path
    p connection.parser.headers
    p connection.parser.body
  end

  def self.response connection
    p connection.parser.status_code
    p connection.parser.headers
    p connection.parser.body
  end
end


Intervention.on(:request) {|c| puts "\n-------------------\nreceived request\n-------------------\n"}
Intervention.on(:response) {|c| puts "\n-------------------\nreceived response\n-------------------\n"}
Intervention.callback Test
Intervention.start

binding.pry