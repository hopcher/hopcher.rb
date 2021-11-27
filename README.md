### Example

```rb
def on_connection_out(client, socket, node)
    puts "made connection with #{node["localAddress"]} successfully"
end

def on_connection_in(client, s)
    puts "Someone just connected to us"
end

def on_message(client, data, ip, port)
    puts "#{ip}:#{port}> #{data}"
end

client = TCPClient.new "10.0.0.29", "8000", false

client.on(:connection_out, method(:on_connection_out))

client.on(:connection_in, method(:on_connection_in))

client.on(:message, method(:on_message))

client.connect
```