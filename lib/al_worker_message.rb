#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# Messaging system

require "al_worker"
require "thread"
require "sync"
require "timeout"


##
# Broadcast message
#
#(note)
# スレッド間メッセージングシステム。
# 1:nメッセージを実現する。
# （通常の1:1メッセージであれば、Ruby標準のQueueで十分。）
#
class AlWorker::BroadcastMessage

  #@return [Hash <Thread,Queue>]  スレッドとメッセージキュー
  attr_reader :threads


  ##
  # constructor
  #
  def initialize()
    @threads = {}
  end


  ##
  # ブロードキャストメッセージ受信予約
  #
  def attach()
    @threads[ Thread.current.object_id ] = [ Thread.current, Queue.new() ]
  end


  ##
  # ブロードキャストメッセージ受信予約解除
  #
  def detach()
    @threads.delete( Thread.current.object_id )
  end


  ##
  # メッセージ送信
  #
  #@param [Object] msg  送信メッセージ
  #
  def send( msg )
    @threads.values.each do |th,q|
      if th.alive?
        q.push( msg )
      else
        @threads.delete( th.object_id )
      end
    end
  end


  ##
  # メッセージ受信
  #
  #@return [Object]  受信メッセージ
  #@note
  # メッセージがなければ、送られるまで停止する。
  #
  def receive()
    @threads[ Thread.current.object_id ][1].pop()
  rescue NoMethodError
    raise "Maybe used receive() without attach()."
  end


  ##
  # メッセージがあるか問い合わせ
  #
  #@return [Boolean]  メッセージが無い時、true。
  #
  def empty?()
    @threads[ Thread.current.object_id ][1].empty?()
  rescue NoMethodError
    raise "Maybe used empty?() without attach()."
  end

end



##
# Numbered message queue
#
#(note)
# 接続が断続的になる場合（httpなど）を想定して、 クライアントが
# メッセージの取りこぼしがないように、番号付きでキューを構成する。
# 番号はトランザクションIDと称し、単調増加させる。
# クライアントはトランザクションIDを指定して、どこまでメッセージを
# 得たかを管理する。
# メッセージオブジェクトは、Hashのみ。
# スレッドセーフに実装してある。
#
class AlWorker::NumberedMessage
  include Sync_m

  #@return [Integer]  トランザクションID　1から単調増加する。
  attr_reader :tid

  #@return [Integer]  キューサイズ
  attr_reader :max_queue_size

  #@return [Array<Hash>]  メッセージキュー
  attr_reader :queue

  #@return [BroadcastMessage]  send/receiveのためのBroadcastMessage
  attr_reader :bc


  ##
  # constructor
  #
  #@param [Integer]  size  キューサイズ
  #
  def initialize( size = 10 )
    super()     # Sync_m needs.
    @tid = 0
    @max_queue_size = size
    @queue = []
    @bc = AlWorker::BroadcastMessage.new()
  end


  ##
  # キューへメッセージ追加
  #
  #@param [Hash] msg メッセージ
  #@return [Integer] トランザクションID
  #
  #@note
  #  :TIDが予約語としてメッセージ内に追加される。
  #
  def add( msg )
    synchronize( Sync::EX ) {
      msg[:TID] = (@tid += 1)
      @queue << msg
      while @queue.size > @max_queue_size
        @queue.shift
      end
      return @tid
    }
  end


  ##
  # キューからメッセージを取り出し
  #
  #@param [Integer] tid  トランザクションID
  #@return [Array<Hash>] メッセージの配列。まだ指定された番号のトランザクションが発生していない場合は、空配列を返す。
  #@return [NilClass]    メッセージキューからすでに消えている場合
  #
  def get( tid )
    synchronize( Sync::SH ) {
      i = @queue.size - 1
      return []  if i < 0 || @queue[i][:TID] < tid

      while i >= 0
        if @queue[i][:TID] <= tid
          return @queue[i..-1]
        end
        i -= 1
      end
    }
    return nil
  end


  ##
  # キューへメッセージ追加するとともに receive待ちをしているスレッドを起こす
  #
  #@param [Hash] msg メッセージ
  #@return [Integer] トランザクションID
  #
  def send( msg )
    tid = add( msg )
    @bc.send( tid )
    Thread.pass
    return tid
  end


  ##
  # キューからメッセージを取り出し
  #
  #@param [Integer] tid  トランザクションID
  #@return [Array<Hash>] メッセージの配列。
  #@return [NilClass]    メッセージキューからすでに消えている場合
  #@note
  # トランザクションがまだ発生していない場合、次メッセージがsendされるまで待つ。
  #
  def receive( tid )
    @bc.attach()
    ret = get( tid )
    if ret == []
      tid = @bc.receive()
      ret = get( tid )
    end
    return ret

  ensure
    @bc.detach()
  end


  ##
  # キュー内の最小TIDを返す
  #
  #@return [Integer]   最小TID
  #
  def tid_min()
    return @queue[0] == nil ? 0 : @queue[0][:TID]
  end


  ##
  # メッセージ受信繰り返し動作
  #
  #@param [Integer] tid  初期トランザクションID
  #@param [Integer] timeout 待ち時間タイムアウト
  #
  #@note
  # メッセージを待ち、指示された動作を実行することを繰り返す。
  # タイムアウト以外では帰らない。
  #
  def cycle( tid, timeout = nil )
    @bc.attach()
    loop do
      # get messages.
      msg = get( tid )
      tid = @tid  if msg == []
      msg = @queue.dup()  if msg == nil         # message has gone.

      # process each messages.
      msg.each do |m|
        yield( m )
        tid = m[:TID]
      end
      tid += 1

      # wait next messages.
      Timeout::timeout( timeout ) {
        @bc.receive()     # waiting message.
      }
    end

  rescue Timeout::Error
    return nil

  ensure
    @bc.detach()
  end
  
end
