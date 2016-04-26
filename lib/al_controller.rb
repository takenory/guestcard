#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.

require 'al_session'


##
# Aloneコントローラクラス
#
# コントローラ名、ステート名、アクション名、この３つのパラメータにより、
# 全体を駆動する。
# コントローラは、パラメータ ctrl= で、アクションは、action= で指定される。
# ただし、これらパラメータのパースはメインモジュールにて行い、ここでは、
# その値のエイリアスをもらっている。
# 併せて、(ちょっとした工夫により）コントローラごとに名前空間分離した
# 専用セッション変数を持たせる機能もインプリメントしてある。
#
class AlControllerBase

  # コントローラ名（メインモジュールの値のエイリアス）
  CTRL = Alone::ctrl

  ##
  # コントローラローカルのセッション変数の動作定義
  #
  class AlControllerSession
    ##
    # 変数の保存
    #
    #@param [Symbol] k キー
    #@param [Object] v 値
    #
    def self.[]=( k, v )
      AlSession["AL_#{CTRL}_#{k}"] = v
    end

    ##
    # 変数の取得
    #
    #@param  [Symbol] k キー
    #@return [Object] 値
    #
    def self.[]( k )
      return AlSession["AL_#{CTRL}_#{k}"]
    end

    ##
    # 変数の消去
    #
    #@param  [Symbol] k キー
    #
    def self.delete( k )
      AlSession::delete( "AL_#{CTRL}_#{k}" )
    end

    ##
    # 変数の全消去
    #
    def self.delete_all()
      AlSession::delete( "AL_STATE_#{CTRL}" )
      prefix = "AL_#{CTRL}_"
      AlSession::keys().each do |k|
        if k.to_s.index( prefix ) == 0
          AlSession::delete( k )
        end
      end
    end
  end


  #@return [String] ステート
  attr_reader :state

  #@return [String] 動作選出されたメソッド名
  attr_reader :respond_to

  #@return [Bool] ステートエラー時に、ランタイムエラーを起こすかのフラグ
  attr_reader :flag_raise_state_error


  ##
  # getter: session
  #
  #@return [AlControllerSession] コントローラローカルセッションの操作オブジェクト
  #
  def session()
    return AlControllerSession
  end


  ##
  # ログ出力
  #
  #@see Alone.log()
  #
  def log( arg = nil, severity = nil, progname = nil )
    Alone.log( arg, severity, progname )
  end


  ##
  # ステートエラー発生の制御
  #
  #@param [Bool] flag  ステートエラー時に、ランタイムエラーを起こすかのフラグ
  #
  def raise_state_error( flag = true )
    @flag_raise_state_error = flag
  end


  ##
  # アプリケーション実行開始（内部メソッド）
  #
  #@note
  # 各パラメータによりユーザコードを選択し、実行する。
  #
  def _exec()
  # アクション名（メインモジュールの値のエイリアス）
    action = Alone::action
    if action.empty?
      action << "index" # 同じオブジェクトを使うために << を使う。
    end

    @respond_to = "from_#{@state}_action_#{action}"
    if respond_to?( @respond_to )
      return __send__( @respond_to )
    end

    @respond_to = "state_#{@state}_action_#{action}"
    if respond_to?( @respond_to )
      return __send__( @respond_to )
    end

    @respond_to = "action_#{action}"
    if respond_to?( @respond_to )
      return __send__( @respond_to )
    end

    @respond_to = "state_#{@state}"
    if respond_to?( @respond_to )
      return __send__( @respond_to )
    end

    # 実行すべきメソッドが見つからない場合
    @respond_to = ""
    no_method_error()
  end


  ##
  # メソッドエラーの場合のエラーハンドラ
  #
  #@note
  # ステートエラーは、raise_state_error()で動作を本番時とデバッグ時を切り替えられる。
  # エラー表示などしたければ、当メソッドをオーバライドすることもできる。
  #
  def no_method_error()
    if @state.to_s.empty?
      Alone::add_http_header( "Status: 404 Not Found" )
      raise "No action defined. CTRL: #{CTRL}, ACTION: #{Alone::action}"
    end

    if @flag_raise_state_error
      Alone::add_http_header( "Status: 404 Not Found" )
      raise "No state/action defined. CTRL: #{CTRL}, STATE: #{@state}, ACTION: #{Alone::action}"
    end

    Alone::add_http_header( "Status: 204 No Content" )
  end


  ##
  # 現在のステートを宣言する
  #
  #@param [String]  state ステート文字列
  #
  def set_state( state )
    @state = state.to_s
    AlSession["AL_STATE_#{CTRL}"] = @state
  end
  alias state= set_state


  ##
  # デバグ用：各パラメータの表示用文字列を返す
  #
  #@return [String]  デバグ用文字列
  #
  def self.debug_dump()
    r = "CTRL: #{CTRL}, STATE: #{$AlController.state}, ACTION: #{Alone::action}, RESPOND TO: #{$AlController.respond_to}\n"
    r << "SESSION VAR:\n"
    prefix = "AL_#{CTRL}_"
    AlSession::keys().each do |k|
      if k.to_s.index( prefix ) == 0
        r << "  #{k.to_s[prefix.size,100]}: #{AlSession[k]}\n"
      end
    end
    return r
  end

end


##
# ユーザアプリ用コントローラ
#
class AlController < AlControllerBase

  # フレームワーク側で生成するクラスを保存
  @@suitable_class = self

  def self.suitable_class
    return @@suitable_class
  end

  def self.inherited( subclass )
    @@suitable_class = subclass
  end

end


##
# コントローラローカルセッションを他のクラスでも使うためのモジュール
#
module AlControllerSession
  ##
  # getter: session
  #
  #@return [AlControllerSession] コントローラローカルセッションの操作オブジェクト
  #
  def session()
    return AlControllerBase::AlControllerSession
  end
end


##
# 実行開始
#
if ! defined? AL_CTRL_NOSTART
  begin
    # コントローラを初期化し、必要なユーザコードを読み込む
    Dir.chdir( File.join( AL_CTRL_DIR, AlControllerBase::CTRL ) )
    require './main.rb'

  rescue Exception => ex
    Alone::handle_error( ex )
  end

  # ユーザコードの実行
  Alone::main() {
    $AlController = AlController.suitable_class.allocate
    $AlController.instance_variable_set( :@state, AlSession["AL_STATE_#{AlController::CTRL}"] )
    $AlController.__send__( :initialize )
    $AlController._exec()
  }
end
