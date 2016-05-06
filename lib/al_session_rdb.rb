#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# セッションマネージャ RDB バインディング
#
# (実装)
#  ランダムにセッションIDを生成し、クッキーを利用してセッションを特定する。
#  セッション変数の値は、サーバ側にのみ保管し、ブラウザには渡さない。
#
# (注意)
#  DBwrapperのデフォルト接続が当クラスに奪われるので、それを使っている
#  場合はアプリケーション側の書き換えが必要になるかもしれない。
# 
# (準備)
# テーブル作成
#  create table sessions (session_id varchar(32) primary key, data text, 
#   updated_at timestamp);
# セッション消去をcronに仕掛ける
#  delete from sessions where updated_at < 
#    CURRENT_TIMESTAMP - cast('2 hours' as interval);
#
# (al_config.rb中への設定)
#  RDB wrapperモジュールを指定
#   AL_SESS_RDBW = "al_rdbw_postgres"
#  セッション保存のためのRDB接続情報
#   AL_SESS_CONN = "host=localhost dbname=db1 user=user1 password=pass1"


require AL_SESS_RDBW


##
# セッションマネージャ
# セッション変数を管理する。
#
#@note
# セッション変数には、String,Numeric,Hashなど、基本的な（requreの必要のない）
# オブジェクトのみ保存すること。
# 実装上は任意のオブジェクトが保存できるが、セッション復帰が難しくなる。
# また、アプリケーション側にとっても、アプリケーションのバージョンアップが
# 難しくなるので、基本オブジェクトに限定したほうが良い。
#@see
# コントローラを使う場合は、コントローラローカルセッションも参照の事。
#
class AlSession

  # セッションを保存するテーブル名
  TBL_SESSIONS = "sessions"

  # セッションID
  @@session_id = nil
  
  # セッション変数のHash
  @@session_var = {}

  # 保存RDBWオブジェクト
  @@session_rdbw = nil


  ##
  # デバッグ用：セッション変数をすべて出力する。
  #@return [String]  セッション変数の内容
  #
  def self.debug_dump()
    r = "AlSession::debug_dump() outputs\n"
    r << "Session ID '#{get_session_id()}'\n"
    @@session_var.each do |k,v|
      r << "#{k} => '#{v.to_s}'\n"
    end
    return r
  end


  ##
  # セッションIDの取得
  #@return [String]     セッションID
  #
  def self.get_session_id()
    return @@session_id
  end


  ##
  # セッション開始（内部メソッド）
  #
  #@note
  # 当ファイルをインクルードした段階で自動スタートするので、
  # 明示的に呼び出す必要は無い。
  #
  def self._start()
    @@session_rdbw = AlRdbw.connect( AL_SESS_CONN )
    @@session_id = Alone::get_cookie( :ALSESSID )

    #
    # すでにセッションIDが割り当て済みの場合
    #
    if /\A[a-zA-Z0-9]{32}\Z/ =~ @@session_id
      begin
        rows = @@session_rdbw.select( "select data from #{TBL_SESSIONS} where session_id='#{@@session_id}';" )
        @@session_var = Marshal.load( eval( rows[0][:data] ) )
        return

      rescue
        # データが何らかの理由により存在しないか、不正なデータである。
        # よって、セッションID未割り当ての場合と同じ処理へ移行する。
      end
    end

    #
    # セッションID未割り当ての場合
    #
    retry_count = 0
    begin
      @@session_id = make_session_id()
      @@session_rdbw.insert( TBL_SESSIONS, { :session_id=>@@session_id, :updated_at=>Time.now } )
      Alone::set_cookie( :ALSESSID, @@session_id, nil, '/' )

    rescue
      retry_count += 1
      if retry_count > 10
        puts "Can't create session data in database. Fix AL_SESS_* parameter in al_config.rb file."
        exit
      end
      retry
    end
  end


  ##
  # 終了処理（内部メソッド）
  #
  #@note
  # セッションの終了ではなく、htmlの接続ごとの終了。
  #
  def self._end()
    #
    # DBへセッション変数を登録
    #
    data = { :data=>Marshal.dump( @@session_var ).dump, :updated_at=>Time.now }
    @@session_rdbw.update( TBL_SESSIONS, data, {:session_id=>@@session_id} )
  end


  ##
  # セッションIDの変更
  #
  #@note
  # 任意のタイミングで現在のセッションIDを無効化、新しいIDを付与する。
  #
  def self.change_session_id()
    #
    # 今のセッションファイルを無効化（消去）
    #
    @@session_rdbw.delete( TBL_SESSIONS, {:session_id=>@@session_id} )

    #
    # 新しいセッションidおよびファイルを作る
    #
    retry_count = 0
    begin
      @@session_id = make_session_id()
      @@session_rdbw.insert( TBL_SESSIONS, { :session_id=>@@session_id, :updated_at=>Time.now } )
      Alone::set_cookie( :ALSESSID, @@session_id, nil, '/' )

    rescue
      retry_count += 1
      if retry_count > 10
        raise "Can't create session."
      end
      retry
    end
  end


  ##
  # セッション変数の取得
  #
  #@param  [String,Symbol]  k   セッション変数名 key
  #@return [Object]             値
  #
  def self.[]( k )
    return @@session_var[k.to_sym]
  end


  ##
  # セッション変数の設定
  #
  #@param  [String,Symbol]  k   セッション変数名 key
  #@param  [Object]         v   値
  #
  def self.[]=( k, v )
    @@session_var[k.to_sym] = v
  end


  ##
  # セッション変数のキー一覧
  #
  #@return [Array<Symbol>]      キーの配列
  #
  def self.keys()
    return @@session_var.keys()
  end


  ##
  # セッション変数の消去
  #
  #@param  [String,Symbol]  k   セッション変数名 key
  #
  def self.delete( k )
    @@session_var.delete( k.to_sym )
  end


  ##
  # セッション変数の全消去
  #
  def self.delete_all()
    @@session_var.clear()
  end


  ##
  # セッションの終了
  #
  #@note
  # セッションそのものを終了する。
  # セッション変数もセッションIDも（クッキーも）消去する。
  #
  def self.destroy()
    delete_all()
    Alone::delete_cookie( :ALSESSID, '/' )
    @@session_rdbw.delete( TBL_SESSIONS, {:session_id=>@@session_id} )
    @@session_id = nil
  end


  ##
  # セッションIDの生成
  #
  #@note
  # 最大36**32のランダム値でセッションID（32文字の英数字）を生成
  #
  private
  def self.make_session_id()
    return "00000000000000000000000000000000#{rand(63340286662973277706162286946811886609896461828096).to_s(36)}"[-32,32]
  end
end


#
# 初期化コード
#
AlSession::_start()
END {
  AlSession::_end()
}
