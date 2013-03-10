require 'socket'

s = TCPSocket.new 'localhost', 9292
s.write "GET /tests/hijack-partial http/1.1\r\n"
s.write "Host: localhost\r\n"
s.write "\r\n"

loop do
  c = s.getc
  break if c.nil?
  print c
end

puts "closing socket"

s.close
