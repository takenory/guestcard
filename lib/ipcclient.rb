#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2014 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# IPC client; telnet like interface.
#

require "socket"
$readline = require "readline"


##
# データ受信（スレッド）
#
def receive_data( sock )
  while txt = sock.gets
    print "  #{txt}"
  end
  puts "\n(Socket closed by peer.)"
  exit 0
end


##
# データ送信  from STDIN
#
def send_data_stdin( sock )
  while txt = $stdin.gets
    sock.write txt
  end
  puts "\n(terminate)"
end


##
# データ送信  using READLINE
#
def send_data_readline( sock )
  while txt = Readline.readline( "", true )
    if /^\\i *(.*)$/ =~ txt
      send_file( sock, $1 )
      next
    end

    sock.puts txt
  end
  puts "\n(terminate)"
end


##
# ファイル送信
#
def send_file( sock, filename )
  begin
    file = File.open( filename )
  rescue =>ex
    puts ex.message
    return
  end

  while txt = file.gets
    sock.puts txt
  end
  file.close
end



#
# main
#
$socket_node = ARGV[0]
sock = UNIXSocket.open( $socket_node )
puts "(Socket ready '#{$socket_node}')"

Thread.start { receive_data( sock ) }
if $readline
  send_data_readline( sock )
else
  send_data_stdin( sock )
end
