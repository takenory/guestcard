#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# ログインマネージャ　メイン処理
#

require 'al_form'
require 'al_template'
require 'al_session'


##
# ログインマネージャ
#
class AlLogin

  #@return [AlForm]     ログイン用フォームオブジェクト
  attr_reader :form

  #@return [String]     ログイン画面テンプレートファイル名
  attr_reader :template_name

  #@return [Hash]       フォームから受け取った値
  attr_reader :values

  ##
  # constructor
  #
  #@param [String] template_name        テンプレートファイル名(option)
  #
  def initialize( template_name = nil )
    @template_name = template_name || "al_login.rhtml"

    @form = AlForm.new( [
        AlText.new( 'user_id', :label=>'ユーザID',
                    :required=>true, :validator=>/^[\w_-]+$/ ),
        AlText.new( 'password', :label=>'パスワード',
                    :required=>true, :validator=>/^[\w_-]+$/ ),
      ] )
  end


  ##
  # 認証用画面の表示
  #
  def display_confirm_screen()
    AlTemplate.run( @template_name, binding )
    AlSession[:al_login_token] = 'DUMMY_ID_D0Sv3ebV32'
  end


  ##
  # ログインメイン処理
  #
  #@return [True]       ログイン成功
  #@return [False]      ログイン失敗
  #@note
  # ログインの一連の処理を実施し、ログインが成功したら trueを返す。
  # ログイン前にリクエストされたURIは保存されるが、POSTデータは保存されないので、
  # 必要なら自分で処理するか、当システム内へ内包する方法を立案すべき。
  #
  def login()
    # 初めてのアクセスならフォームを表示して終了。
    if ! @form.fetch_request( 'POST' )
      display_confirm_screen()
      return false
    end

    # セッションが使えるか確認。NGならあきらめる。
    if ! AlSession[:al_user_id] &&
        AlSession[:al_login_token] != 'DUMMY_ID_D0Sv3ebV32'
      puts "You must enable cookie. <br>"
      puts "And click bellow, jump login page.<br>"
      puts "<a href=\"#{AL_LOGIN_URI}\">To Login page.</a><br>"
      exit
    end

    # テンポラリログアウト
    AlSession::delete( :al_user_id )
    AlSession::delete( :al_login_token )

    # バリデーション。NGなら、フォーム表示して終了。
    if ! @form.validate()
      display_confirm_screen()
      return false
    end
    @values = @form.values.dup

    # 認証。ユーザコードでオーバライドされた confirm()が呼び出される。
    # NGなら、フォームを表示して終了。
    if ! confirm()
      @form.add_message( "ユーザIDまたはパスワードが違います。" )
      display_confirm_screen()
      return false
    end
      
    # 認証成功。
    # セッションへユーザIDを保存して、ログイン済みであることを明示する。
    AlSession::change_session_id()
    AlSession[:al_user_id] = @values[:user_id]

    # ログイン前にリクエストされていたURIがあれば、そこへリダイレクトし、
    # 呼び出し元へは戻らない。
    if AlSession[:al_request_uri]
      Alone::redirect_to( AlSession[:al_request_uri] )
      AlSession.delete( :al_request_uri )
      Alone::send_http_headers()
      exit
    end

    return true
  end
  

  ##
  # ログアウト
  #
  #@note
  # セッション情報を削除して、ログアウトとする。
  #
  def self.logout()
    AlSession::destroy()
  end


  ##
  # 認証
  #
  #@return [True]       認証成功
  #@return [False]      認証失敗
  #@note
  # サブクラスでオーバライドする。
  #
  def confirm()
    return false
  end
end
