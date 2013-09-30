module OutputIntervention
  def self.on_request t
    puts "[%s:%d] >>> [%s:%d]" % [ t.to_client.peeraddr[2], t.to_client.peeraddr[1], t.to_server.peeraddr[2], t.to_server.peeraddr[1]]
  end

  def self.on_response t
    puts "[%s:%d] <<< [%s:%d]" % [ t.to_client.peeraddr[2], t.to_client.peeraddr[1], t.to_server.peeraddr[2], t.to_server.peeraddr[1]]
  end
end