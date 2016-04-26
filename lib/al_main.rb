#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# メインモジュール

##
# Aloneメインクラス
#
#@note
# Aloneのベースとなる機能を、まとめている。
#
class Alone

  # escape_html用定数テーブル
  CHAR_ENT_REF = {'<'=>'&lt;', '>'=>'&gt;', '&'=>'&amp;', '"'=>'&quot;', '\''=>'&#39;', "\r\n"=>'<br>', "\r"=>'<br>', "\n"=>'<br>' }

  #@return [Array]  httpヘッダ
  @@headers = [ "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0" ]

  #@return [Hash,NilClass]  クッキー
  @@cookies = nil

  #@return [Boolean]  リダイレクトするかのフラグ
  @@flag_redirect = false

  #@return [Boolean]  httpヘッダを送ったかのフラグ
  @@flag_send_http_headers = false

  #@return [String]  コントローラ名
  @@ctrl = ""

  #@return [String]  アクション名
  @@action = ""

  #@return [Logger]  ロガーオブジェクト
  @@log = nil


  ##
  # Getter コントローラ名
  #
  #@return [String]  コントローラ名
  #
  def self.ctrl()
    return @@ctrl
  end

  ##
  # Getter アクション名
  #
  #@return [String]  アクション名
  #
  def self.action()
    return @@action
  end


  ##
  # メイン
  #
  #@note
  # ユーザコードがブロックで渡されるので、それを実行する。
  # 例外はすべてキャッチして、正当なhtmlで表示する。
  #
  def self.main()
    # リダイレクトするなら、ヘッダ出力のみで終了（htmlコンテンツは必要ない）
    if @@flag_redirect
      send_http_headers()
      exit
    end

    begin
      yield()
      send_http_headers()

    rescue Exception => ex
      handle_error( ex )
    end
  end


  ##
  # エラーハンドラ
  #
  def self.handle_error( ex )
    if ex.class == SystemExit
      send_http_headers()
    else
      __send__( AL_ERROR_HANDLER, ex )
      log( ex )
    end

    exit
  end


  ##
  # エラーハンドラ：静的ページを表示
  #
  def self.handle_error_static_page( ex )
    status_code = nil
    status_message = nil

    # check status code in @@headers.
    @@headers.each do |h|
      if /^Status: (\d+)(.*)$/ =~ h
        status_code = $1
        status_message = $1 + $2
      end
    end
    if ! status_code
      status_code = "500"         # default 500 Internal Server Error
      status_message = "Internal Server Error"
      Alone::add_http_header( "Status: 500 Internal Server Error" )
    end

    # display error page.
    send_http_headers()
    begin
      print File.read( "#{AL_BASEDIR}/templates/#{status_code}.html" )
    rescue
      print status_message
    end
  end


  ##
  # エラーハンドラ：エラー詳細表示
  #
  def self.handle_error_display( ex )
    add_http_header( "Status: 500 Internal Server Error" )
    send_http_headers()

    puts AL_TEMPLATE_HEADER
    puts AL_TEMPLATE_BODY
    puts '<h1 class="al-error-display">Alone: Error detected.</h1>'
    puts "<h2 class=\"al-error-display\">#{ex.class} occurred.</h2>"
    puts '<pre class="al-error-display">'
    puts '    ' + escape_html( ex.message )
    puts '</pre>'

    puts '<h2 class="al-error-display">Backtrace</h2>'
    puts '<pre class="al-error-display">'
    ex.backtrace.each do |bt|
      puts '    ' + escape_html( bt )
    end
    puts '</pre>'

    puts '<h2 class="al-error-display">Environment</h2>'
    puts '<pre class="al-error-display">'
    `env`.split("\n").each do |e|
      puts '    ' + escape_html( e )
    end
    puts '</pre>'
    puts AL_TEMPLATE_FOOTER
  end


  ##
  # httpヘッダの追加
  #
  #@param [String]  header       ヘッダ文字列。"Tag: message."　形式
  #@note
  # 実際にhttpヘッダが送られる前に、使用する必要がある。
  # httpヘッダは、send_http_headers() メソッドで送られる。
  # 典型的には、最初にユーザコードで文字列などが表示される直前に、
  # ヘッダが出力されるので、それまでに使用する。
  #
  def self.add_http_header( header )
    @@headers << header.chomp.gsub( /\r?\n[^ \t]|\r[^\n \t]/, ' ' )
  end


  ##
  # httpヘッダの削除
  #
  #@param [String]  header       ヘッダ文字列。"Cache-Control"等
  #@note
  # 実際にhttpヘッダが送られる前に、使用する必要がある。
  # デフォルトで送信されるヘッダ Cache-Control: を止めることができる。
  #@see Alone::add_http_header()
  #
  def self.delete_http_header( header )
    @@headers.delete_if { |a| a.start_with?( header ) }
  end


  ##
  # httpヘッダの送信
  #
  #@note
  # 送信済みなら何もしないので、何度よんでも問題ない。
  #
  def self.send_http_headers()
    return  if @@flag_send_http_headers
    @@flag_send_http_headers = true

    flag_content_type = false
    @@headers.each do |h|
      puts h
      flag_content_type = true  if h.start_with?( "Content-Type:" )
    end
    if ! flag_content_type 
      print "Content-Type: text/html; charset=#{AL_CHARSET}\n"
    end
    print "\n"
  end


  ##
  # クッキーの取得
  #
  #@param [String,Symbol] name  クッキー名
  #@return [String]       値
  #@return [NilClass]     引数で与えられたクッキーが定義されていない場合 nil
  #
  def self.get_cookie( name )
    if ! @@cookies
      @@cookies = {}
      http_cookie = ENV['HTTP_COOKIE']
      return nil  if ! http_cookie

      cookies = http_cookie.split( ';' )
      cookies.each do |c|
        (k,v) = c.split( '=', 2 )
        next if ! v
        @@cookies[k.strip.to_sym] = decode_uri_component( v )
      end
    end
    
    return @@cookies[name.to_sym]
  end


  ##
  # クッキーの設定
  #
  #@param [String] name         クッキー名
  #@param [String] value        値
  #@param [String] expire       有効期限
  #@param [String] path         パス
  #@note
  # httpヘッダに出力する関係上、ヘッダ出力前にコールする必要がある。
  #
  def self.set_cookie( name, value, expire = nil, path = nil )
    cookie = "Set-Cookie: #{name}=#{encode_uri_component( value )}"
    cookie << "; expires=#{expire.to_s}"  if expire
    cookie << "; path=#{path}"  if path
    @@headers << cookie
  end


  ##
  # クッキーの消去
  #
  #@param [String] name         クッキー名
  #@param [String] path         パス
  #@note
  # httpヘッダに出力する関係上、ヘッダ出力前にコールする必要がある。
  #
  def self.delete_cookie( name, path = nil )
    # 既にヘッダへ出力予約されているものがあれば削除
    target = "Set-Cookie: #{name}="
    @@headers.delete_if { |h| h.start_with?( target ) }

    cookie = "Set-Cookie: #{name}=; expires=Thu, 08-Jun-1944 00:00:00 GMT"
    cookie << "; path=#{path}"  if path
    @@headers << cookie
  end


  ##
  # リダイレクト設定
  #
  #@param [String] uri          リダイレクト先のURI
  #
  def self.redirect_to( uri )
    if @@flag_send_http_headers
      raise "HTTP header was already sent."
    end
    raise "Invalid URI"  if /[\r\n]/ =~ uri

    @@headers << "Location: #{uri}"
    @@headers << "Status: 302 Found"
    @@flag_redirect = true
  end


  ##
  # URIエンコード
  #
  #@param [String]  s   ソース文字列
  #@return [String]     エンコード済み文字列
  #
  def self.encode_uri_component( s )
    a = s.to_s.dup
    a.force_encoding( Encoding::ASCII_8BIT )
    a.gsub( /[^a-zA-Z0-9!'\(\)*\-._~]/ ) { |c| "%#{c.unpack('H2')[0]}" }
  end


  ##
  # URIデコード
  #
  #@param [String]  s   ソース文字列
  #@return [String]     デコード済み文字列
  #
  def self.decode_uri_component( s )
    a = s.to_s.dup.force_encoding( Encoding::ASCII_8BIT )
    a.gsub!( /%([0-9a-fA-F]{2})/ ) { $1.hex.chr }
    a.force_encoding( AL_CHARSET )
    # TODO: UTF-8（あるいはその他の漢字コード）として無効なコードが来たらどうする？
  end


  ##
  # リクエストされたURIを返す
  #
  #@return [String]     リクエストされたURI
  #
  def self.request_uri()
    if ENV['REQUEST_URI']
      return ENV['REQUEST_URI']
    end

    if ENV['QUERY_STRING']
      return "#{ENV['SCRIPT_NAME']}?#{ENV['QUERY_STRING']}"
    end

    return ENV['SCRIPT_NAME']
  end


  ##
  # リンク用のURIを生成する
  #
  #@param [Hash] arg    引数ハッシュ
  #@return [String]     生成したURI
  #@option arg [String] :ctrl           コントローラ名
  #@option arg [String] :action         アクション名
  #@option arg [String] :(oters)        その他のパラメータ
  #@note
  # このメソッドは、escape_html()した値を返さない。
  # 生成した値は、アトリビュート値にもテンプレートにも使われる。
  # 少々危険な気もするが、エスケープはテンプレートエンジンの仕事にしなければ
  # アプリケーションが破綻する。
  #
  def self.make_uri( arg = {} )
    uri = "#{ENV['SCRIPT_NAME']}?ctrl=#{arg[:ctrl] || @@ctrl}"
    uri << "&action=#{arg[:action]}"  if arg[:action]

    arg.each do |k,v|
      next if k == :ctrl || k == :action
      if v.class == Array
        v.each do |v1|
          uri << "&#{k}=#{encode_uri_component(v1)}"
        end
      else
        uri << "&#{k}=#{encode_uri_component(v)}"
      end
    end

    return uri
  end


  ##
  # html特殊文字のエスケープ
  #
  #@param [String] s    対象文字列
  #@return [String]     変換後文字列
  #
  def self.escape_html( s )
    return s.to_s.gsub( /[<>&"']/, CHAR_ENT_REF )
  end


  ##
  # html特殊文字のエスケープ with 改行文字
  #
  #@param [String] s    対象文字列
  #@return [String]     変換後文字列
  #@note
  # html特殊文字のエスケープに加え、改行文字を<br>タグへ変更する。
  #
  def self.escape_html_br( s )
    return s.to_s.gsub( /([<>&"']|\r\n|\r|\n)/, CHAR_ENT_REF )
  end


  ##
  # クォート文字をバックスラッシュでエスケープする
  #
  #@param [String] s    対象文字列
  #@return [String]     変換後文字列
  #@note
  # 対象は、シングルクォート、ダブルクォート、バックスラッシュ、NULL
  #
  def self.escape_backslash( s )
    s.to_s.gsub( /['"\\\x0]/ ) { |q| "\\#{q}" }
  end


  ##
  # ログ出力
  #
  #@param [String,Object] arg   エラーメッセージ
  #@param [Symbol] severity     ログレベル :fatal, :error ...
  #@param [String] progname     プログラム名
  #@return [Logger]             Loggerオブジェクト
  #
  def self.log( arg, severity = nil, progname = nil )
    return nil  if ! defined? AL_LOG_DEV
    require "logger"

    if ! @@log
      @@log = Logger.new( AL_LOG_DEV, AL_LOG_AGE, AL_LOG_SIZE )
      @@log.level = Logger::INFO
    end

    s = { :fatal=>Logger::FATAL, :error=>Logger::ERROR, :warn=>Logger::WARN,
          :info=>Logger::INFO, :debug=>Logger::DEBUG }[ severity ]

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
  # Alone標準出力トラップクラス
  #
  #@note
  # httpヘッダを出すために、一時的に出力をトラップする。
  #
  class OutputTrap
    def write( s )
      $stdout = STDOUT
      $stderr = STDOUT
      Alone::send_http_headers()
      print( s )
    end

    def flush()
    end
  end



  ##
  # 初期化
  #
  def self._start()
    if ENV.has_key?("GATEWAY_INTERFACE")
      query_string = ENV["QUERY_STRING"] || ""
      /(^|&)ctrl=([a-zA-Z0-9_\-\/]*)/ =~ query_string
      @@ctrl = $2.to_s
      /(^|&)action=([a-zA-Z0-9_\-\/]*)/ =~ query_string
      @@action = $2.to_s
      $stdout = OutputTrap.new
      $stderr = $stdout
    end
    Encoding.default_external = AL_CHARSET
  end
  _start()
end
