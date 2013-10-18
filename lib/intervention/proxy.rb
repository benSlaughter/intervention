module Intervention
  # Proxy
  # @attr_reader name [String] The proxies name
  # @attr_reader state [String] the current running state of the proxy
  # @attr_accessor listen_port The default listening port for the proxy server socket
  # @attr_accessor host_address The default address for the forward socket to send to
  # @attr_accessor host_port The default port number for the forward socket to send to
  #
  class Proxy
    include Observable

    attr_reader :name
    attr_accessor :listen_port, :host_address, :host_port, :agents

    # Overiting the default class inspect
    #
    def inspect
      "#<Proxy:%s:%s listen:%s host:%s port:%s>" % [@name,@state,@listen_port,@host_address,@host_port]
    end

    # Intervention::Proxy#initalize
    # @param name [String] the given name of the proxy
    # Keyword Arguments:
    # @param listen_port [Integer] The default listening port for the proxy server socket
    # @param host_address [Hash] The default address for the forward socket to send to
    # @param host_port [Integer] The default port number for the forward socket to send to
    #
    def initialize name, **kwargs, &block
      @name          = name
      @state         = "stopped"
      @listen_port   = kwargs[:listen_port] || Intervention.listen_port
      @host_address  = kwargs[:host_address] || Intervention.host_address
      @host_port     = kwargs[:host_port] || Intervention.host_port
      @agents        = kwargs[:agents] || Intervention.agents
      @events        = Hashie::Mash.new

      instance_eval(&block) if block_given?
      agents.each {|agent| add_observer(agent)}
      start if (kwargs.nil? ? Intervention.auto_start : kwargs[:auto_start])
    end

    # Call a specifit event
    # and notify all agents of this proxy
    # @param transaction [Intervention::Transaction] each event is passed the current transaction
    # @param event [Symbol] the event that has been triggered
    #
    def call_event transaction, event
      @events[event].call transaction if @events.has_key? event
      notify_observers(transaction, event)
    end

    # finds a proxies agent by the name
    # returns the first agent that is found with a matching name
    # @param agent_name [String, Symbol] the name that is assigned to the agent
    #
    def agent agent_name
      @agents.detect {|a| a.name == agent_name.to_sym }
    end

    # Returns Boolean value on the proxies status
    #
    def stopped?
      @state == "stopped" ? true : false
    end

    # Returns Boolean value on the proxies status
    #
    def running?
      @state == "running" ? true : false
    end

    # Configure Proxy values
    #
    # proxy_object.configure do |proxy|
    #   proxy.listen_port = 4000
    #   proxy.host_address = "www.google.com"
    # end
    #
    # [listen_port = Integer]   The listening port for the proxy server socket
    # [host_address = String]   The address for the forward socket to send to
    # [host_port = Integer]     The port number for the forward socket to send to
    #
    def configure
      yield self
    end

    # Start Proxy
    # creates starts the proxy server in a thread
    # returns control to the caller
    #
    def start
      if stopped?
        @state = "running"
        @server_socket = TCPServer.new @listen_port
        Thread.new { run_proxy }
      end
    end

    # Stop proxy
    # Stops the server socket
    #
    def stop
      if running?
        @server_socket.close
        @state = "stopped"
      end
    end

    private

    # Creates an event using the passed block
    # @param event [Symbol] the name of the event
    # @param block [Proc] the block that is run upon the event being triggered
    #
    def on event, &block
      @events[event.to_sym] = block
    end

    # Method that starts the thread and loops the proxy
    # Passes self (proxy) into each transaction
    # Ensures that all sockets are closed in the event of an error
    #
    def run_proxy
      loop do
        new_socket = @server_socket.accept
        Thread.new { Transaction.new(self, new_socket) }
      end

    ensure
      puts "Quitting proxy #{@name}..."
      @server_socket.close if @server_socket
      new_socket.close if defined? new_socket
    end
  end
end