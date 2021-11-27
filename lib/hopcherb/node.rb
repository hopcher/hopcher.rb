# A way of representing nodes in the peer to peer area
class Node
    def initialize(ip, port, socket)
        @ip = ip
        @port = port
        @socket = socket
        # The socket connection of this node to us
    end

    def address
        "#{@ip}:#{@port}"
    end

    def port
        @port
    end

    def ip
        @ip
    end

    def socket
        @socket
    end
end