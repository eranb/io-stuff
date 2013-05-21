require 'socket'

Process.setrlimit(:NOFILE, Process.getrlimit(:NOFILE).first)

if ARGV.size < 2
  abort "Usage: #{__FILE__} <host> <port-range> <port-range>\n" + 
  "e.g #{__FILE__} google.com 20..23 70..90"
end

ports = []
pool  = []
sockets = []

host = ARGV[0]
ARGV[1..-1].map {|s| s.split('..').map(&:to_i)}.each { |s,e| pool += (s..e).to_a } 

remote = ->(port) { Socket.pack_sockaddr_in(port, host) }
handle = ->() {
  now = Time.now + 10
  loop do
    _,available,_ = IO.select([], sockets, [], now-Time.now)

    (available or break).each do |socket|
      begin
        socket.connect_nonblock socket.remote_address
      rescue Errno::EISCONN
        ports.push sockets.delete(socket).remote_address.ip_port
      rescue Errno::EINVAL
        sockets.delete socket
      end
    end
  end

  sockets.map(&:close)
  sockets.clear
}

while ( port = pool.shift )
  begin
    socket = Socket.new(:INET, :STREAM)
    sockets.push socket
    socket.connect_nonblock remote.(port)
  rescue Errno::EINPROGRESS
    print "#{port} "
  rescue Errno::EMFILE
    handle.()
    retry
  rescue Exception
  end
end

handle.()

puts "\nOpen Ports:\n#{ports.inspect}"
