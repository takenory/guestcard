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
# IPCサーバ
#
class AlWorker::Ipc

  ##
  # object finalizer
  #
  def self.finalizer( socketfile )
    proc {
      File.unlink( socketfile ) rescue 0
    }
  end


  ##
  # クライアント接続ソケットの作成
  #
  #@param [String]  socketfile IPCソケットファイル
  #
  def self.open( socketfile = nil, &block )
    # ソケットファイル、デフォルト値を使う
    socketfile ||= File.join( AlWorker::DEFAULT_WORKDIR, AlWorker::DEFAULT_NAME )
    AlWorker::IpcClient.open( socketfile, &block )
  end



  #@return [String]  IPCソケットファイル
  attr_reader :socketfile

  #@return [Integer] IPCソケットのread/writeモード (chmodの値)
  attr_accessor :chmod

  #@return [String]  コールバックメソッドのプレフィックス
  attr_accessor :cb_prefix

  #@return [String]  接続後のバナー表示
  attr_accessor :banner


  ##
  # constructor
  #
  #@param [String] socketfile  IPCソケットファイル
  #
  def initialize( socketfile = nil )
    @socketfile = socketfile
    @cb_prefix = "ipc"
  end


  ##
  # 実行開始
  #
  #@param [AlWorker] obj  ワーカオブジェクト
  #
  def run( obj )
    @me = obj
    @socketfile ||= File.join( @me.workdir, @me.name )

    # ソケットオープン
    begin
      UNIXSocket.open( @socketfile ) {}
      raise "IPC socket file '#{@socketfile}' was already in use."

    rescue Errno::ENOENT
      # ok continue.
    rescue Errno::ECONNREFUSED
      # file exist but not use.
      File.unlink( @socketfile ) rescue 0
    end

    server = UNIXServer.new( @socketfile )
    File.chmod( @chmod, @socketfile )  if @chmod

    ObjectSpace.define_finalizer( self, self.class.finalizer( @socketfile ) )

    # サービス開始
    Thread.start {
      loop do
        Thread.start( server.accept ) { |sock|
          _start_service( sock )
        }
      end
    }
  end


  private
  ##
  # IPCサービス開始
  #
  #@note
  # 一つのIPC接続は、このメソッド内のloopで連続処理する。
  #
  def _start_service( sock )
    AlWorker.log( "START CONNECTION.", :debug, "IPC(#{sock.object_id})" );
    sock.puts @banner  if @banner
    loop do
      # リクエスト行取得
      begin
        req = sock.gets
        return  if ! req
        req.chomp!
      end while req.empty?
      req.force_encoding( Encoding::UTF_8 )
      AlWorker.log( "receive '#{req}'", :debug, "IPC(#{sock.object_id})" );

      # リクエスト実行
      ret = _assign_method( sock, req )
      break if !ret
    end

  rescue Exception => ex
    raise ex  if ex.class == SystemExit
    AlWorker.log( ex )

  ensure
    sock.close if ! sock.closed?
    AlWorker.log( "END CONNECTION.", :debug, "IPC(#{sock.object_id})" );
  end


  ##
  # 実行メソッド割り当て
  #
  #@param [Socket] sock IPCソケット
  #@param [String] req リクエスト行
  #@return [Boolean]  続けてリクエストを受け付けるか、接続を切るかのフラグ
  #
  def _assign_method( sock, req )
    (cmd,param) = AlWorker.parse_request( req )
    method_name_sync = "#{@cb_prefix}_#{cmd}"
    method_name_async = "#{@cb_prefix}_a_#{cmd}"

    [@me,self].each do |obj|
      if obj.respond_to?( method_name_sync, true )
        AlWorker.log( "assign method '#{method_name_sync}'", :debug, "IPC(#{sock.object_id})" );
        AlWorker.mutex_sync.synchronize {
          return obj.__send__( method_name_sync, sock, param )
        }
      end
      if obj.respond_to?( method_name_async, true )
        AlWorker.log( "assign method '#{method_name_async}'", :debug, "IPC(#{sock.object_id})" );
        return obj.__send__( method_name_async, sock, param )
      end
    end

    _command_not_implemented( sock, param )
  end


  ##
  # 実装されていないコマンドを受信した場合の挙動
  #
  def _command_not_implemented( sock, param )
    AlWorker.log( "Command not implemented.", :debug, "IPC(#{sock.object_id})" );
    sock.puts "501 Error Command not implemented."
    return true
  end


  ##
  # quitコマンドの処理
  #
  def ipc_a_quit( sock, param )
    sock.puts "200 OK quit."
    return false
  end


  ##
  # get_values IPCコマンドの処理
  #
  #@note
  # (IPC command)
  # Receive all values
  #  get_values
  #  get_values {}
  #
  # Receive selected
  #  get_values key
  #  get_values {"key":"key1"}
  #  get_values {"key":["key1","key2"]}
  #
  def ipc_a_get_values( sock, param )
    json = @me.get_values_json( param[""] || param["key"] )
    sock.puts "200. OK", json, ""
    return true
  end


  ##
  # get_values_wt IPCコマンドの処理
  #
  #@note
  # (IPC command)
  #  get_values_wt {"key":"key", "timeout":5}
  #
  def ipc_a_get_values_wt( sock, param )
    (json,flag) = @me.get_values_json_wt( param[""] || param["key"],
                                             param["timeout"] )
    status = flag ? "200. OK" : "200. OK But no lock."

    sock.puts status, json, ""
    return true
  end


  ##
  # set_values IPCコマンドの処理
  #
  #@note
  # (IPC command)
  #  set_values key=value
  #  set_values {"key":"value"}
  #
  def ipc_a_set_values( sock, param )
    catch(:error_exit) {
      throw :error_exit  if param.empty?
      if param[""]
        (k,v) = param[""].split( "=", 2 )
        throw :error_exit  if k == "" || v == nil || v == ""
        param = { k => v }
      end

      @me.set_values( param )
      sock.puts "200 OK"
      return true
    }

    sock.puts "400 Bad Request."
    return true
  end

end



##
# IPCクライアント
#
#@note
# 通信のデータ形式はJSONで行うが、ユーザプログラムとのデータ授受は、
# HashでもJSONでも行える。
# @valuesアクセッサは、専用メソッドとキャッシュを用意した。
# ただし、Hashで授受する場合のみキャッシュを使う。
#
class AlWorker::IpcClient < UNIXSocket

  #@return [Hash] AlWorker::Ipc#valuesのキャッシュ
  attr_reader :values

  #@return [String] 通信ステータスコード
  attr_reader :status_code


  ##
  # constructor
  #
  def initialize( path )
    super
    @values = {}
    @status_code = ""
  end


  ##
  # IPC 呼び出し
  #
  #@param [String]      cmd  コール先メソッド名
  #@param [Hash,String] arg  パラメータ
  #@return [Hash]       リプライデータ
  #@return [NilClass]   IPCがクローズされた
  #
  def call( cmd, arg = {} )
    json = call_json( cmd, arg )
    return nil if ! json
    JSON.parse( json ) rescue {}
  end


  ##
  # IPC 呼び出し JSON版
  #
  #@param [String]      cmd  コール先メソッド名
  #@param [Hash,String] arg  パラメータ
  #@return [String]     リプライデータ JSON文字列
  #@return [NilClass]   IPCがクローズされた
  #
  def call_json( cmd, arg = {} )
    arg = arg.to_json  if arg.class == Hash
    self.puts "#{cmd} #{arg}"

    @status_code = self.gets
    if @status_code == nil
      @status_code = "503 Service Unavailable. IPC was closed."
      return nil
    end
    @status_code.chomp!
    if @status_code[3] == " "
      return "{}"
    end

    json = ""
    while txt = self.gets
      txt.chomp!
      break if txt == ""
      json << txt
    end
    return json
  end


  ##
  # valueのセッター（単一値）
  #
  #@param [String]  key  キー
  #@param [Object]  val  値
  #
  def set_value( key, val )
    @values[ key ] = val
    call_json( "set_values", { key=>val } )
  end


  ##
  # valueのセッター（複数値）
  #
  #@param [Hash] values  セットする値
  #
  def set_values( values )
    @values.merge!( values )
    call_json( "set_values", values )
  end


  ##
  # valueのゲッター タイムアウトなし（単一値／複数値）
  #
  #@param [String,Array] key  キー
  #@return [Object,Hash]      値
  #
  def get_value( key = nil )
    ret = call( "get_values", key: key )
    return nil  if ! @status_code.start_with?( "200" )

    if key
      @values.merge!( ret )
      return @values[ key ]  if key.class == String
    else
      @values = ret
    end
    return ret
  end
  alias get_values get_value


  ##
  # valueのゲッター  タイムアウト付き（単一値／複数値）
  #
  #@param [String,Array] key     キー
  #@param [Numeric]      timeout タイムアウト時間
  #@return [Object,Hash]         値
  #@note
  # 内部キャッシュ @valuesに保存する。
  #
  def get_value_wt( key = nil, timeout = nil )
    ret = call( "get_values_wt", key: key, timeout: timeout )
    return nil  if ! @status_code.start_with?( "200" )
    locked = (@status_code == "200. OK")

    if key
      @values.merge!( ret )
      return @values[ key ],locked  if key.class == String
    else
      @values = ret
    end
    return ret,locked
  end
  alias get_values_wt get_value_wt

end



##
# IPC action モジュール
#
# Aloneコントローラへ、IPCのためのアクションを追加する。
# (usage) 
#    class AlController
#      include AlWorker::IpcAction
#
module AlWorker::IpcAction
  ##
  # AlWorker::Ipc コールアクション
  #
  #@note
  # (GET)
  #  http://*.cgi?ctrl=xxx&action=ipc&ipc=IPCNAME&arg=ARGUMENT_encoded_by_json
  # (POST)
  #  http://*.cgi?ctrl=xxx&action=ipc
  #  (postdata)  ipc=IPCNAME&arg=ARGUMENT_encoded_by_json
  #
  def action_ipc()
    # http (ajax) リクエスト取得
    case ENV["REQUEST_METHOD"]
    when "GET"
      req = AlForm.prefetch_request_get()
    when "POST"
      req = AlForm.prefetch_request_post()
    else
      return
    end

    # IPC接続
    if @ipc
      # ipcオブジェクトが与えられた。
      # use it.
    elsif @ipc_name
      # ソケット名が与えられた。
      @ipc = AlWorker::Ipc.open( @ipc_name )
    elsif req[:ipc_name]
      # httpリクエストで与えられた。
      @ipc = AlWorker::Ipc.open( req[:ipc_name] )
    else
      # デフォルト値を使用。
      @ipc = AlWorker::Ipc.open()
    end

    # IPC 呼び出し
    json = @ipc.call_json( req[:ipc], req[:arg] )
    puts %Q!["#{@ipc.status_code}", #{json}]!
  end


  ##
  # AlWorker::Ipc コールアクション for Server sent event.
  #
  #@note
  #  プロトコル仕様のため、以下の理由で IPC through JavaScript が使えない。
  #   * httpヘッダでパラメータ(ID)を送られる
  #   * Content-Typeが、text/event-streamである（JSONデータではない）
  #  そのため、IPCのパススルー機能(puts/gets)を使ってサーバーと直接chatする。
  #
  def action_ssev()
    # http (ajax) リクエスト取得
    case ENV["REQUEST_METHOD"]
    when "GET"
      req = AlForm.prefetch_request_get()
    when "POST"
      req = AlForm.prefetch_request_post()
    else
      return
    end

    # IPC接続
    if @ipc
      # ipcオブジェクトが与えられた。
      # use it.
    elsif @ipc_name
      # ソケット名が与えられた。
      @ipc = AlWorker::Ipc.open( @ipc_name )
    elsif req[:ipc_name]
      # httpリクエストで与えられた。
      @ipc = AlWorker::Ipc.open( req[:ipc_name] )
    else
      # デフォルト値を使用。
      @ipc = AlWorker::Ipc.open()
    end

    # 先立ってコメントを送ることによって接続を確実にする。
    Alone.add_http_header( "Content-Type: text/event-stream" )
    print ": comment for established connection.\n\n"
    $stdout.flush

    # IPC リクエスト
    id = ENV["HTTP_LAST_EVENT_ID"].to_i
    @ipc.puts "#{req[:ipc]} #{req.merge({LAST_EVENT_ID: id}).to_json}"

    # リプライ
    while txt = @ipc.gets
      print txt
      $stdout.flush  if txt == "\n"
    end
  end

end
