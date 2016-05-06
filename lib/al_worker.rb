#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require "logger"
require "etc"
require "sync"
require "json"
require "digest"


##
# ワーカースーパークラス
#
class AlWorker

  DEFAULT_WORKDIR = "/tmp"
  DEFAULT_NAME = "al_worker"
  LOG_SEVERITY = { :fatal=>Logger::FATAL, :error=>Logger::ERROR,
    :warn=>Logger::WARN, :info=>Logger::INFO, :debug=>Logger::DEBUG }

  #@return [Logger]  ロガー
  @@log = nil

  #@return [Mutex]  同期実行用mutex
  @@mutex_sync = Mutex.new


  ##
  # 同期実行用mutexのアクセッサ
  #
  def self.mutex_sync()
    return @@mutex_sync
  end



  ##
  # ログ出力
  #
  #@param [String,Object] arg   エラーメッセージ
  #@param [Symbol] severity     ログレベル :fatal, :error ...
  #@param [String] progname     プログラム名
  #@return [Logger]             Loggerオブジェクト
  #
  def self.log( arg = nil, severity = nil, progname = nil )
    return nil  if ! @@log

    s = LOG_SEVERITY[ severity ]
    if arg.class == String
      @@log.add( s || Logger::INFO, arg, progname )

    elsif arg.is_a?( Exception )
      @@log.add( s || Logger::ERROR, "#{arg.class} / #{arg.message}", progname )
      @@log.add( s || Logger::ERROR, "BACKTRACE: \n  " + arg.backtrace.join( "\n  " ) + "\n", progname )

    elsif arg != nil
      @@log.add( s || Logger::INFO, arg.to_s, progname )
    end
    return @@log
  end


  ##
  # IPC定形リクエストからコマンドとパラメータを解析・取り出し
  #
  #@param [String] req  リクエスト
  #@return [String] コマンド
  #@return [Hash] パラメータ
  #
  def self.parse_request( req )
    (cmd,param) = req.split( " ", 2 )
    return cmd,{}  if param == nil
    param.strip!
    return cmd,{}  if param.empty?
    return cmd,( JSON.parse( param ) rescue { ""=>param } )
  end


  ##
  # IPC定形リプライ
  #
  #@param [Socket]  sock    返信先ソケット
  #@param [Integer] st_code ステータスコード
  #@param [String]  st_msg  ステータスメッセージ
  #@param [Hash]    val     リプライデータ
  #@return [True]
  #@note
  # 定形リプライフォーマット
  #   (ステータスコード) "200. Message"
  #   (JSONデータ)       { .... }
  #  JSONデータは付与されない場合がある。
  #  その判断は、ステータスコードの数字直後のピリオドの有無で行う。
  #
  def self.reply( sock, st_code, st_msg, val = nil )
    sock.puts ("%03d" % st_code) + (val ? ". " : " ") + st_msg
    if val
      sock.puts val.to_json, ""
    end
    return true

  rescue Errno::EPIPE
    Thread.exit
  end


  ##
  # ステートマシンで無視するイベントの記述
  #
  #@note
  # クラス定義中に、na :state_XXX_event_YYY の様に記述する。
  #
  def self.na( method_name )
    define_method( method_name ) { |*args| }
  end



  #@return [Hash] 外部提供を目的とする値のHash　IPCの関係でキーは文字列のみとする。
  attr_accessor :values

  #@return [Sync] @values の reader writer lock
  attr_reader :values_rwlock

  #@return [String]  ワークファイルの作成場所
  attr_accessor :workdir

  #@return [String]  pidファイル名（フルパス）
  attr_accessor :pid_filename

  #@return [String]  ログファイル名（フルパス）
  attr_accessor :log_filename

  #@return [String] ユニークネーム
  attr_reader :name

  #@return [String] 現在実行中のRubyスクリプトの名前を表す文字列 $PROGRAM_NAME
  attr_accessor :program_name

  #@return [String] 実行権限ユーザ名
  attr_accessor :privilege

  #@return [String]  ステート（ステートマシン用）
  attr_reader :state

  #@return [Boolean] ソフトウェアウォッチドッグ機能を使用
  attr_accessor :software_watchdog



  ##
  # constructor
  #
  #@param [String] name  識別名
  #
  def initialize( name = nil )
    @values = {}
    @values_rwlock = Sync.new
    @workdir = DEFAULT_WORKDIR
    @name = name || DEFAULT_NAME
    @state = ""

    Signal::trap( :QUIT, proc{ signal_quit } )
  end


  ##
  # 基本的なオプションの解析
  #
  def parse_option( argv = ARGV )
    i = 0
    while i < argv.size
      case argv[i]
      when "-d"
        @flag_debug = true
      when "-p"
        @pid_filename = argv[i += 1]
      when "-l"
        @log_filename = argv[i += 1]
      end
      i += 1
    end
  end


  ##
  # シグナルハンドラ　SIGQUIT
  #
  #@note
  # デバグ用
  #  状態をファイルに書き出す。
  #  画面があれば、表示する。
  #
  def signal_quit()
    save_values()

    if STDOUT.isatty
      puts "\n===== @values ====="
      @values.keys.sort.each do |k|
        puts "#{k}=> #{@values[k]}"
      end
    end
  end


  ##
  # valueのセッター（単一値）
  #
  #@param [String]  key  キー
  #@param [Object]  val  値
  #
  def set_value( key, val )
    @values_rwlock.synchronize( Sync::EX ) { @values[ key.to_s ] = val }
  end


  ##
  # valueのセッター（複数値）
  #
  #@param [Hash] values  セットする値
  #
  def set_values( values )
    @values_rwlock.synchronize( Sync::EX ) { @values.merge!( values ) }
  end


  ##
  # valueのゲッター タイムアウトなし（単一値）
  #
  #@param [String] key  キー
  #@return [Object]     値
  #@note
  # 値はdupして返す。
  #
  def get_value( key )
    @values_rwlock.synchronize( Sync::SH ) {
      return @values[ key.to_s ].dup rescue @values[ key.to_s ]
    }
  end


  ##
  # valueのゲッター タイムアウトなし（複数値）
  #
  #@param [Array]  keys  キーの配列
  #@return [Hash]        値
  #@note
  # 値はdupするが、簡素化のためにディープコピーは行っていない。
  # 文字列では問題ないが、配列などが格納されている場合は注意が必要。
  #
  def get_values( keys )
    ret = {}
    @values_rwlock.synchronize( Sync::SH ) {
      keys.each do |k|
        ret[ k.to_s ] = @values[ k.to_s ].dup rescue @values[ k.to_s ]
      end
    }
    return ret
  end


  ##
  # valueのゲッター  タイムアウト付き（単一値）
  #
  #@param [String]  key     キー
  #@param [Numeric] timeout タイムアウト時間
  #@return [Object]         値
  #@return [Boolean]        ロック状態
  #@note
  # 値はdupして返す。
  #
  def get_value_wt( key, timeout = 1 )
    locked = false
    (timeout * 10).times {
      locked = @values_rwlock.try_lock( Sync::SH )
      break if locked
      sleep 0.1
    }

    return (@values[ key.to_s ].dup rescue @values[ key.to_s ]), locked

  ensure
    @values_rwlock.unlock( Sync::SH ) if locked
  end


  ##
  # valueのゲッター  タイムアウト付き（複数値）
  #
  #@param [Array]   keys    キーの配列
  #@param [Numeric] timeout タイムアウト時間
  #@return [Object]         値
  #@return [Boolean]        ロック状態
  #@note
  # 値はdupするが、簡素化のためにディープコピーは行っていない。
  # 文字列では問題ないが、配列などが格納されている場合は注意が必要。
  #
  def get_values_wt( keys, timeout = 1 )
    locked = false
    (timeout * 10).times {
      locked = @values_rwlock.try_lock( Sync::SH )
      break if locked
      sleep 0.1
    }

    ret = {}
    keys.each do |k|
      ret[ k.to_s ] = @values[ k.to_s ].dup rescue @values[ k.to_s ]
    end
    return ret, locked

  ensure
    @values_rwlock.unlock( Sync::SH ) if locked
  end


  ##
  # valueのゲッター  JSON版　タイムアウトなし
  #
  #@param [String,Array] key  取得する値のキー文字列
  #@return [String]  保存されている値のJSON文字列
  #
  def get_values_json( key = nil )
    @values_rwlock.synchronize( Sync::SH ) {
      if key.class == Array
        ret = {}
        key.each { |k| ret[ k ] = @values[ k ] }
        return ret.to_json
      end
      return ( key ? { key => @values[key] } : @values ).to_json
    }
  end


  ##
  # valuesのゲッター  JSON版 タイムアウト付き
  #
  #@param [String,Array] key  取得する値のキー文字列
  #@param [Numeric] timeout タイムアウト時間
  #@return [String]  保存されている値のJSON文字列
  #@return [Boolean] ロック状態
  #
  def get_values_json_wt( key = nil, timeout = nil )
    locked = false
    timeout ||= 1       # can't change. see AlWorker::Ipc#ipc_a_get_values_wt()
    (timeout * 10).times {
      locked = @values_rwlock.try_lock( Sync::SH )
      break if locked
      sleep 0.1
    }
    if key.class == Array
      ret = {}
      key.each { |k| ret[ k ] = @values[ k ] }
      return ret.to_json, locked
    end
    return ( key ? { key => @values[key] } : @values ).to_json, locked

  ensure
    @values_rwlock.unlock( Sync::SH ) if locked
  end


  ##
  # 値(@values)保存
  #
  #@note
  # 排他処理なし。
  # バックアップファイルを３つまで作成する。
  #
  def save_values()
    filename = File.join( @workdir, @name ) + ".values"
    File.rename( filename + ".bak2", filename + ".bak3" ) rescue 0
    File.rename( filename + ".bak1", filename + ".bak2" ) rescue 0
    File.rename( filename,           filename + ".bak1" ) rescue 0

    File.open( filename, "w" ) { |f|
      f.puts "DATE: #{Time.now}"
      f.puts "NAME: #{@name}"
      f.puts "SELF: #{self.inspect}"
      f.puts "VALUES: \n#{@values.to_json}"
    }
    File.open( File.join( @workdir, @name ) + ".sha1", "w" ) { |file|
      file.write( Digest::SHA1.file( filename ) )
    }
  end


  ##
  # 値(@values)読み込み
  #
  def load_values( filename = nil )
    filename ||= File.join( @workdir, @name ) + ".values"
    digest = Digest::SHA1.file( filename ) rescue nil
    return nil if ! digest      # same as file not found.

    digestfile = File.join( File.dirname(filename), File.basename(filename,".*") ) + ".sha1"
    digestfile_value = File.read( digestfile ) rescue nil
    if digestfile_value
      return nil  if digest != digestfile_value
    end

    json = ""
    File.open( filename, "r" ) { |f|
      while txt = f.gets
        break if txt == "VALUES: \n"
      end
      if txt == "VALUES: \n"
        while txt = f.gets
          json << txt
        end
      end
    }
    return nil  if json == ""
    begin
      @values = JSON.parse( json )
      return true
    rescue
      return false
    end
  end


  ##
  # デーモンになって実行
  #
  def daemon()
    if @flag_debug
      run()
    else
      run( :daemon )
    end
  end


  ##
  # 実行開始
  #
  #@param [Symbol] modes 動作モード　nul デーモンにならずに実行
  #                                  :daemon デーモンで実行
  #                                  :nostop デーモンにならずスリープもしない
  #                                  :nopid プロセスIDファイルを作らない
  #                                  :nolog ログファイルを作らない
  #                                  :exit_idle_task アイドルタスクが終了したら
  #                                                  プロセスも終了する
  #
  def run( *modes )
    # 実効権限変更（放棄）
    if @privilege
      uid = Etc.getpwnam( @privilege ).uid
      Process.uid = uid
      Process.euid = uid
    end

    # ログ準備
    if modes.include?( :nolog )
      @@log == nil
    elsif @@log == nil
      @log_filename ||= File.join( @workdir, @name ) + ".log"
      @@log = Logger.new( @log_filename, 3 )
      @@log.level = @flag_debug ? Logger::DEBUG : Logger::INFO
    end

    if ! modes.include?( :nopid )
      @pid_filename ||= File.join( @workdir, @name ) + ".pid"
      # 実行可／不可確認
      if File.directory?( @pid_filename )
        puts "ERROR: @pid_filename is directory."
        exit( 64 )
      end
      if File.exist?( @pid_filename )
        puts "ERROR: Still work."
        exit( 64 )
      end

      # プロセスIDファイル作成
      # (note) pid作成エラーの場合は、daemonになる前にここで検出される。
      File.open( @pid_filename, "w" ) { |file| file.write( Process.pid ) }
    end

    # 常駐処理
    if modes.include?( :daemon )
      Process.daemon()
      # プロセスIDファイル再作成
      if ! modes.include?( :nopid )
        File.open( @pid_filename, "w" ) { |file| file.write( Process.pid ) }
      end
    end
    if @program_name
      $PROGRAM_NAME = @program_name
    end

    # 終了時処理
    at_exit {
      if ! modes.include?( :nopid )
        File.unlink( @pid_filename ) rescue 0
      end
      AlWorker.log( "finish", :info, @name )
    }

    # 初期化２
    AlWorker.log( "start", :info, @name )
    begin
      initialize2()
    rescue Exception => ex
      raise ex  if ex.class == SystemExit
      AlWorker.log( ex )
      raise ex  if STDERR.isatty
      exit( 64 )
    end

    # アイドルタスク
    if respond_to?( :idle_task, true )
      Thread.start {
        Thread.current.priority -= 1
        begin
          idle_task()
        rescue Exception => ex
          raise ex  if ex.class == SystemExit
          AlWorker.log( ex )
          if STDERR.isatty
            STDERR.puts ex.to_s
            STDERR.puts ex.backtrace.join("\n") + "\n"
          end
        end
        exit  if modes.include?( :exit_idle_task )
      }
    end

    # メインスレッド停止
    return  if modes.include?( :nostop )
    sleep
  end


  ##
  # 初期化２
  #
  #@note
  # 常駐後に処理をさせるには、これをオーバライドする。
  #
  def initialize2()
  end


  ##
  # ログ出力
  #
  #@see AlWorker.log()
  #
  def log( arg = nil, severity = nil, progname = nil )
    AlWorker.log( arg, severity, progname )
  end


  ##
  # IPC定形リプライ
  #
  #@see AlWorker.reply()
  #
  def reply( sock, st_code, st_msg, val = nil )
    AlWorker.reply( sock, st_code, st_msg, val )
  end


  ##
  # ステートマシン　実行メソッド割り当て
  #
  #@param [String]  event  イベント名
  #@param [Array]   args   引数
  #
  def trigger_event( event, *args )
    @respond_to = "from_#{@state}_event_#{event}"
    if respond_to?( @respond_to )
      AlWorker.log( "st:#{@state} ev:#{event} call:#{@respond_to}", :debug, @name )
      return __send__( @respond_to, *args )
    end

    @respond_to = "state_#{@state}_event_#{event}"
    if respond_to?( @respond_to )
      AlWorker.log( "st:#{@state} ev:#{event} call:#{@respond_to}", :debug, @name )
      return __send__( @respond_to, *args )
    end

    @respond_to = "event_#{event}"
    if respond_to?( @respond_to )
      AlWorker.log( "st:#{@state} ev:#{event} call:#{@respond_to}", :debug, @name )
      return __send__( @respond_to, *args )
    end

    @respond_to = "state_#{@state}"
    if respond_to?( @respond_to )
      AlWorker.log( "st:#{@state} ev:#{event} call:#{@respond_to}", :debug, @name )
      return __send__( @respond_to, *args )
    end

    # 実行すべきメソッドが見つからない場合
    @respond_to = ""
    no_method_error( event )
  end


  ##
  # メソッドエラーの場合のエラーハンドラ
  #
  def no_method_error( event )
    raise "No action defined. state: #{@state}, event: #{event}"
  end


  ##
  # 現在のステートを宣言する
  #
  #@param [String]  state ステート文字列
  #
  def set_state( state )
    @state = state.to_s
    AlWorker.log( "change state to #{@state}", :debug, @name )
  end
  alias state= set_state
  alias next_state set_state

end
