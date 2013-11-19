require 'pry'
require 'intervention'

prox = Intervention.new "proxy", auto_start: true do
  configure do |proxy|
    proxy.listen_port = 4000
    proxy.host_port = 80
    proxy.host_address = 'localhost'
  end

  on :request do |t|
    puts "[%s:%d] >>> [%s:%d]" % [ t.to_client.peeraddr[2], t.to_client.peeraddr[1], t.to_server.peeraddr[2], t.to_server.peeraddr[1]]
  end

  on :response do |t|
    puts "[%s:%d] <<< [%s:%d]" % [ t.to_client.peeraddr[2], t.to_client.peeraddr[1], t.to_server.peeraddr[2], t.to_server.peeraddr[1]]
  end
end

binding.pry