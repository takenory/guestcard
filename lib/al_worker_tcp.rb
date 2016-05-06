#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require "al_worker"
require "socket"

##
# TCPサーバ
#
class AlWorker::Tcp

  #@return [String] リスンアドレス
  attr_accessor :address

  #@return [Integer] リスンポート
  attr_accessor :port

  #@return [Symbol]  動作モード :thread :process
  attr_accessor :mode_service

  #@return [String]  コールバックメソッドのプレフィックス
  attr_accessor :cb_prefix

  #@return [String]  接続後のバナー表示
  attr_accessor :banner


  ##
  # constructor
  #
  #@param [String] address リスンアドレス
  #@param [Integer] port   リスンポート
  #
  def initialize( address = "", port = 1944 )
    @address = address
    @port = port
    @mode_service = :thread
    @cb_prefix = "tcp"
  end


  ##
  # 実行開始
  #
  #@param [AlWorker] obj  ワーカオブジェクト
  #@note
  # プロセスモードで動作時は、syncモードと同等の動作になる。
  #
  def run( obj )
    @me = obj
    server = TCPServer.new( @address, @port )

    case @mode_service
    when :process
      Thread.start {
        loop do
          sock = server.accept
          pid = AlWorker.mutex_sync.synchronize { Process.fork() }

          if ! pid
            # child
            _start_service( sock )
            exit!
          end

          # parent
          sock.close
          Process.detach( pid )
        end
      }


    when :thread
      Thread.start {
        loop do
          Thread.start( server.accept ) { |sock|
            _start_service( sock )
          }
        end
      }


    else
      raise "Illegal mode_service"
    end
  end


  private
  ##
  # TCPサービス開始
  #
  #@note
  # 一つのTCP接続は、このメソッド内のloopで連続処理する。
  #
  def _start_service( sock )
    AlWorker.log( "START CONNECTION from #{sock.peeraddr[3]}.", :debug, "TCP(#{sock.object_id})" );
    sock.puts @banner  if @banner
    loop do
      # リクエスト行取得
      begin
        req = sock.gets
        return  if ! req
        req.chomp!
      end while req.empty?
      req.force_encoding( Encoding::UTF_8 )
      AlWorker.log( "receive '#{req}'", :debug, "TCP(#{sock.object_id})" );

      # リクエスト実行
      ret = _assign_method( sock, req )
      break if !ret
    end

  rescue Exception => ex
    raise ex  if ex.class == SystemExit
    AlWorker.log( ex )

  ensure
    sock.close if ! sock.closed?
    AlWorker.log( "END CONNECTION.", :debug, "TCP(#{sock.object_id})" );
  end


  ##
  # 実行メソッド割り当て
  #
  #@param [Socket] sock TCPソケット
  #@param [String] req リクエスト行
  #@return [Boolean]  続けてリクエストを受け付けるか、接続を切るかのフラグ
  #
  def _assign_method( sock, req )
    (cmd,param) = AlWorker.parse_request( req )
    method_name_sync = "#{@cb_prefix}_#{cmd}"
    method_name_async = "#{@cb_prefix}_a_#{cmd}"

    [@me,self].each do |obj|
      if obj.respond_to?( method_name_sync, true )
        AlWorker.log( "assign method '#{method_name_sync}'", :debug, "TCP" );
        AlWorker.mutex_sync.synchronize {
          return obj.__send__( method_name_sync, sock, param )
        }
      end
      if obj.respond_to?( method_name_async, true )
        AlWorker.log( "assign method '#{method_name_async}'", :debug, "TCP" );
        return obj.__send__( method_name_async, sock, param )
      end
    end

    _command_not_implemented( sock, param )
  end


  ##
  # 実装されていないコマンドを受信した場合の挙動
  #
  def _command_not_implemented( sock, param )
    AlWorker.log( "Command not implemented.", :debug, "TCP" );
    sock.puts "501 Error Command not implemented."
    return true
  end


  ##
  # quitコマンドの処理
  #
  def tcp_a_quit( sock, param )
    sock.puts "200 OK quit."
    return false
  end

end
