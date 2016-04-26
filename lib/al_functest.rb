#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# Functional test class.
# (Example to use)
#    require "/path/to/al_config"
#    require "al_functest"
#
#    class MyFuncTest < AlFuncTest
#      ctrl "CONTROLLER_NAME"
#      def test_index
#        get()
#        assert_response( :success )
#      end
#    end


require "fileutils"
require "minitest/unit"
MiniTest::Unit.output = STDOUT
MiniTest::Unit.autorun

# テスト中のセッションファイルを置くディレクトリの操作
if defined?( AL_FUNCTEST_SESS_DIR )
  AL_SESS_DIR << AL_FUNCTEST_SESS_DIR
else
  AL_SESS_DIR << "test-session/"
end
Dir.mkdir( AL_SESS_DIR ) rescue 0
END {
  FileUtils.rm_r( AL_SESS_DIR, :force=>true )
}

# 自動起動なしでコントローラを読み込み
AL_CTRL_NOSTART = true
require "al_controller"


##
# ファンクショナルテストクラス
#
class AlFuncTest < MiniTest::Unit::TestCase
  include AlControllerSession

  @@current_dir = Dir.pwd()

  #@return [String] 出力のバッファ
  attr_reader :response

  ##
  # コントローラの指定
  #
  def self.ctrl( controller_name )
    Alone.ctrl.clear << controller_name.to_s
    Dir.chdir( File.join( AL_CTRL_DIR, AlControllerBase::CTRL ) )
    require './main.rb'
    Dir.chdir( @@current_dir )
  end


  ##
  # Aloneの出力をファイルへ保存する事を指示
  #
  #@param [String] dir_name  保存ディレクトリ名
  #@note ファイル名は、テストメソッド名になる。
  #
  def self.save_response( dir_name )
    OutputTrap::save_response( dir_name )
  end


  ##
  # テストセットアップ（初期化）
  #
  def setup()
    # (note)
    #  al_controller.rb のオブジェクト生成部と合わせること。
    #
    $AlController = AlController.allocate
    $AlController.instance_variable_set( :@state, AlSession["AL_STATE_#{AlController::CTRL}"] )
    $AlController.instance_variable_set( :@flag_raise_state_error, false )
    $AlController.__send__( :initialize )
  end


  ##
  # Alone初期化
  #
  def _init_alone( action )
    # CAUTION: Alone本体の構造と密結合しているので、変更がある場合は双方同時に変更すること。
    Alone.class_variable_set( :@@headers, [ "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0" ] )
    Alone.class_variable_set( :@@cookies, nil )
    Alone.class_variable_set( :@@flag_redirect, false )
    Alone.class_variable_set( :@@flag_send_http_headers, false )

    AlForm.class_variable_set( :@@request_get, {} )
    AlForm.class_variable_set( :@@request_post, {} )

    @response = ""
    $stdout = OutputTrap.new( @response, __name__ )

    Alone::action.clear << action
  end


  ##
  # GETリクエストエミュレート
  #
  #@param [String] action アクション名
  #@param [Hash] parameters GETパラメータ
  #
  def get( action = nil, parameters = {} )
    _init_alone( action.to_s )

    # set parameters
    ENV["REQUEST_METHOD"] = "GET"
    s = ""
    s << "ctrl=#{Alone::ctrl}&"  if ! Alone::ctrl.empty?
    s << "action=#{Alone::action}&"  if ! Alone::action.empty?
    parameters.each do |k,v|
      case v
      when NilClass
        # nothing to do.
      when Array
        v.each { |v1| s << "#{k}=#{Alone::encode_uri_component(v1)}&" }
      else
        s << "#{k}=#{Alone::encode_uri_component(v)}&"
      end
    end
    s.chop!
    ENV["QUERY_STRING"] = s
    ENV["SCRIPT_NAME"] = "/index.rb"
    ENV["REQUEST_URI"] = "/index.rb?#{s}"

    Dir.chdir( File.join( AL_CTRL_DIR, AlControllerBase::CTRL ) )
    $AlController._exec()
    Dir.chdir( @@current_dir )
  end


  ##
  # POSTリクエストエミュレート
  #
  #@param [String] action アクション名
  #@param [Hash] parameters POSTパラメータ
  #
  def post( action = nil, parameters = {} )
    _init_alone( action )

    # set parameters
    ENV["REQUEST_METHOD"] = "POST"
    s = ""
    s << "ctrl=#{Alone::ctrl}&"  if ! Alone::ctrl.empty?
    s << "action=#{Alone::action}&"  if ! Alone::action.empty?
    ENV["QUERY_STRING"] = s
    ENV["SCRIPT_NAME"] = "/index.rb"
    ENV["REQUEST_URI"] = "/index.rb?#{s}"

    # make request
    s = ""
    parameters.each do |k,v|
      case v
      when NilClass
        # nothing to do.
      when Array
        v.each { |v1| s << "#{k}=#{Alone::encode_uri_component(v1)}&" }
      else
        s << "#{k}=#{Alone::encode_uri_component(v)}&"
      end
    end
    s.chop!

    $stdin = EmulateStdin.new( s )
    ENV["CONTENT_LENGTH"] = $stdin.content_length

    Dir.chdir( File.join( AL_CTRL_DIR, AlControllerBase::CTRL ) )
    $AlController._exec()
    Dir.chdir( @@current_dir )
  end


  ##
  # アサーション：HTTPレスポンス（ステータス）コードの確認
  #
  #@param [Integer,Symbol] expect_code 予期しているレスポンスコード
  #  または、レスポンスコードの特定範囲を表すシンボル
  #@param [String] message 表示するメッセージ
  #
  def assert_response( expect_code, message = "" )
    status_code = 200
    Alone.class_variable_get( :@@headers ).each do |line|
      if /^Status: (\d+)/ =~ line
        status_code = $1.to_i
      end
    end

    case expect_code
    when Integer
      assert_equal( status_code, expect_code, message )
    when :success
      assert_equal( status_code, 200, message )
    when :redirect
      assert( 300 <= status_code && status_code <= 399, message )
    when :missing
      assert_equal( status_code, 404, message )
    when :error
      assert( 500 <= status_code && status_code <= 599, message )
    else
      assert( false, "assert_response(): Parameter error." )
    end
  end


  ##
  # アサーション：リダイレクト先が意図したものか確認
  #
  #@param [String,Hash] options  完全なURI
  #  または {:action=>"",...} の形式で、アクション等を指示
  #@param [String] message 表示するメッセージ
  #
  def assert_redirected_to( options, message = "" )
    location = redirect_to_url()
    if ! location
      assert( false, "No redirected." )
    end

    if options.class == String
      assert_equal( options, location, message )
      return
    end

    flag_success = true
    options.each do |k,v|
      text = "#{k}=#{Alone::encode_uri_component(v)}"
      flag_success &&= location.include?( text )
    end
    assert( flag_success, %Q(#{message}\n<"#{options}"> expected. but was\n<"#{location}">) )
  end


  ##
  # コントローラによって割り当てられたインスタンス変数を返す
  #
  #@param [String,Symbol] key インスタンス変数名
  #@return [Object] 変数の値
  #
  def assigns( key )
    $AlController.instance_variable_get( "@#{key}" )
  end


  ##
  # ユーザーに対して送信されるクッキーを返す
  #
  #@return [Hash] クッキーのハッシュ
  #
  def cookies()
    ret = {}
    Alone::class_variable_get( :@@headers ).each do |line|
      if /^Set-Cookie: (\w+)=(\w+)/ =~ line
        ret[$1.to_sym] = Alone::decode_uri_component( $2 )
      end
    end
    return ret
  end


  ##
  # リダイレクト先を示すURL
  #
  #@return [String] リダイレクト先
  #@return [NilClass] リダイレクトが指示されていない場合
  #
  def redirect_to_url()
    Alone.class_variable_get( :@@headers ).each do |line|
      if /^Location: (.+)$/ =~ line
        return $1
      end
    end
    return nil
  end
  alias redirect_to_uri redirect_to_url


  ##
  # ステートをセット
  #
  #@param [String]  state ステート文字列
  #
  def set_state( state )
    $AlController.set_state( state )
  end


  ##
  # ステートを返す
  #
  #@return [String] ステート
  #
  def state()
    return $AlController.state
  end


  ##
  # デバッグ用表示 p
  #
  def p( *arg )
    arg.each { |a| STDOUT.puts a.inspect }
  end


  ##
  # デバッグ用表示 puts
  #
  def puts( *arg )
    STDOUT.puts *arg
  end


  ##
  # デバッグ用表示 print
  #
  def print( *arg )
    STDOUT.print *arg
  end


  ##
  # Alone標準出力トラップクラス
  #
  #@note
  # フレームワークからの出力を、バッファーへ蓄積する。
  # また、必要に応じてファイルへも保存する。
  #
  class OutputTrap

    @@response_save_dir = nil

    def self.save_response( dir_name )
      @@response_save_dir = File.expand_path( dir_name )
    end

    def initialize( buf, name )
      @response = buf
      if @@response_save_dir
        @file = open( File.join( @@response_save_dir, name ), "w" )
      else
        @file = nil
      end
    end

    def write( s )
      @response << s
      @file.print s if @file
    end

    def flush()
    end
  end


  ##
  # stdinエミュレートクラス
  #
  #@note
  # Aloneで必要な最小限の機能のみ実装する。
  #
  class EmulateStdin

    attr_accessor :buffer

    def initialize( s = "" )
      @buffer = s
      @buffer.force_encoding( Encoding::ASCII_8BIT )
    end

    def read( length )
      ret = @buffer.slice!( 0, length )
      return ret
    end

    def gets()
      idx = @buffer.index( "\n" )
      return @buffer.slice!( 0, idx+1 ) if idx
      return nil if @buffer.empty?
      
      ret = @buffer
      @buffer = ""
      return ret
    end

    def content_length()
      return @buffer.length.to_s
    end
  end

end
