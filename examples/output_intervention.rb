class MyAgent
  include Intervention::Engine

  def initialize
    @name = :test
    event :request, :on_request
    event :response, :on_response
  end

  def on_request t
   puts "[%s:%d] >>> [%s:%d]" % [ t.to_client.peeraddr[2], t.to_client.peeraddr[1], t.to_server.peeraddr[2], t.to_server.peeraddr[1]]
  end

  def on_response t
    puts "[%s:%d] <<< [%s:%d]" % [ t.to_client.peeraddr[2], t.to_client.peeraddr[1], t.to_server.peeraddr[2], t.to_server.peeraddr[1]]
  end
end