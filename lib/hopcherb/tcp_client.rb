require 'json'
require 'socket'

include Socket::Constants

require_relative '../models/event_emitter.rb'
class TCPClient < EventEmitter
    ##
    # Creates a new TCPClient described by the +options+
    ##
    def initialize(host, port, encrypted)
        @host = host
        @port = port
        @encrypted = encrypted

        @s_connection = nil

        # Nodes is a hash map which maps a socket to it's node object
        @nodes = Hash.new

        @s_sock_addr = Socket.pack_sockaddr_in(@port, @host)
        # Create a new socket descriptor for the connection with S
        @s_socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM
        # Set the SO_REUSEPORT and SO_REUSEADDR
        @s_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEPORT, 1)
        @s_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
    end

    # This methods connects to the rendzvous server
    # using the options supplied to the constructor
    def connect    
        begin
            @s_socket.connect(@s_sock_addr)
        rescue => exception
            p exception
        end
        
        # Extract the local ip and local port used
        # to connect to the rendzvous server
        s_port = @s_socket.connect_address.ip_port
        s_ip = @s_socket.connect_address.ip_address

        # Construct the endpoint exchange payload
        # which includes the local ip and local port
        # used to connect to the rendzvous server
        payload = {:d => {
            :localAddress => s_ip,
            :localPort => s_port
        }}
        
        # Send the endpoint exchange payload
        @s_socket.write(payload.to_json)

        # Open up a new thread which listens to nodes
        # on the same port used to connect to the rendzvous server
        # this is what creates the hole in the NAT
        Thread.new {
            self.listen(s_port, s_ip)
        }

        # Listen for new packets coming from the rendzvous server
        loop do
            # read the buffer
            buffer = @s_socket.recv(2048)
            # parse it to JSON
            parsed = JSON.parse buffer
            # extract the operation code
            op = parsed["op"]

            # Decide what to do according to the operation code
            # for INITIAL_SOCKETS we want to loop through an array
            # of nodes and connect to them
            # for NEW_CONNECTION we want to connect to the single node
            # so no need to loop here
            case op
            when "INITIAL_SOCKETS"
                parsed["d"].each { |node|
                    self.connect_to_node node
                }
            when "NEW_CONNECTION" 
                self.connect_to_node parsed["d"]
            else
                
            end
        end
    end

    def connect_to_node(node)
        local_address = node["localAddress"]
        local_port = node["localPort"]

        # Fire up a thread which will connect
        # to the local endpoints of the node
        Thread.new {
            connect_to_endpoint(local_address, local_port, node)
        }

    end

    def listen(port, ip)
        # Create a new socket descriptor for the server
        server = Socket.new(AF_INET, SOCK_STREAM, 0)
        # Set the SO_REUSEADDR and SO_REUSEPORT
        server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEPORT, 1)
        server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)

        sock_addr = Socket.sockaddr_in(port, ip)
        # Bind the server to s_port and s_ip
        server.bind(sock_addr)
        # Start listening with a limit of 5 descriptors
        server.listen(5)

        # Accept new nodes
        loop do
            new_socket, addrinfo = server.accept

            @nodes[new_socket] ||= {
                :remote_port => @s_socket.connect_address.ip_port,
                :remote_address => @s_socket.connect_address.ip_address
            }

            Thread.new {
                self.handle_node_connection(new_socket, addrinfo)
            }

            self.emit(:connection_in, self, new_socket) # TODO: Construct a Node object
        end
    end

    def connect_to_endpoint(address, port, node)
        # Create a new socket descriptor for the connection
        socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM
        # Set the SO_REUSEADDR and SO_REUSEPORT
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEPORT, 1)
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)

        sock_addr = Socket.pack_sockaddr_in(port, address)
        
        # Try connecting infinitely until a connection
        # is made successfully
        while true
            begin
                socket.connect(sock_addr)
            rescue => exception
                sleep(5)
                next
            end

            break # Break since a connection was made successfully
        end

        # Connected to the socket successfully
        self.emit(:connection_out, self, socket, node)
    end

    def handle_node_connection(new_socket, addrinfo)
        # Extract the local ip and local port used
        # to connect to us
        remote_port = @s_socket.connect_address.ip_port
        remote_address = @s_socket.connect_address.ip_address

        loop do
            buffer = new_socket.gets("\n")

            # cut the loop if the other node have disconnected
            break if buffer == nil || buffer.length == 0

            buffer = buffer.chomp("\n")

            self.emit(:message, self, buffer, remote_address, remote_port)
        end
    end

    # a getter for nodes
    def nodes
        @nodes
    end
end