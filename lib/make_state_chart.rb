#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# ワーカーのステートマシンを評価して、ステート表を表示する。
#


##
# pickup state / event from a line
#
#@param [String]  line
#@return [String,String,String]  state, event, type
#
def pickup( line )
  if /^\s*(def|alias)\s+from_(\w+)_event_(\w+)/ =~ line
    return $2,$3,"full"
  end

  if /^\s*(def|alias)\s+state_(\w+)_event_(\w+)/ =~ line
    return $2,$3,"full"
  elsif /^\s*(def|alias)\s+state_(\w+)/ =~ line
    return $2,nil,"state"
  end

  if /^\s*(def|alias)\s+event_(\w+)/ =~ line
    return nil,$2,"event"
  end

  # follow na
  if /^\s*na\s+:from_(\w+)_event_(\w+)/ =~ line
    return $1,$2,"/"
  end

  if /^\s*na\s+:state_(\w+)_event_(\w+)/ =~ line
    return $1,$2,"/"
  elsif /^\s*na\s+:state_(\w+)/ =~ line
    return $1,nil,"/"
  end

  if /^\s*na\s+:event_(\w+)/ =~ line
    return nil,$1,"/"
  end

  # follow set_state method
  if /(set_state|next_state|state\s*=)(\s+|\()\s*"?'?:?(\w+)/ =~ line
    return $3,nil,"set_state"
  end
end


##
# display by plain text
#
def display_matrix( matrix )
  return if ! matrix.keys[0]

  state_names = matrix.keys
  event_names = matrix[matrix.keys[0]].keys
  len_ev = 8
  event_names.each { |k| len_ev = k.length  if k.length > len_ev }

  printf( "%*s ", len_ev, "" )
  state_names.each { |st| printf( "%-6s ", st ) }
  printf( "\n" )

  event_names.each do |ev|
    printf( "%-*s ", len_ev, ev )
    state_names.each do |st|
      w = st.length > 6 ? st.length : 6
      printf( "%-*s ", w, matrix[st][ev] )
    end
    printf( "\n" )
  end
end



##
# display by csv
#
def display_matrix_csv( matrix )
  return if ! matrix.keys[0]

  state_names = matrix.keys
  event_names = matrix[matrix.keys[0]].keys

  line = %Q!"",!
  state_names.each { |st| line << %Q!"#{st}",! }
  line.chop!
  puts line

  event_names.each do |ev|
    line = %Q!"#{ev}",!
    state_names.each do |st|
      line << %Q!"#{matrix[st][ev]}",!
    end
    line.chop!
    puts line
  end
end



filename = ARGV[0]
if ! filename
  puts "usage (target filename)"
  exit( 1 )
end

handlers = []
states = {}
events = {}

# read a file
file = open( filename )
while line = file.gets
  st,ev,type = pickup( line )
  next if st == nil && ev == nil

  states[st] = nil  if st
  events[ev] = nil  if ev
  if ! handlers.include?( [st,ev,type] ) && type != "set_state"
    handlers << [st,ev,type]
  end
end
file.close


# make matrix
matrix = {}             # matrix["state"] = { "event"=>"xxx", ... }
states.each do |k,v|
  matrix[k] = events.dup
end

# fill matrix order by week handler
handlers.each do |st,ev,type|
  if st && !ev
    events.keys.each { |e| matrix[st][e] = type }
  end
end
handlers.each do |st,ev,type|
  if !st && ev
    states.keys.each { |s| matrix[s][ev] = type }
  end
end
handlers.each do |st,ev,type|
  if st && ev
    matrix[st][ev] = type
  end
end


display_matrix( matrix )
