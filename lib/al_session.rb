#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# セッションマネージャ
#
# (実装)
#  ランダムにセッションIDを生成し、クッキーを利用してセッションを特定する。
#  セッション変数の値は、サーバ側にのみ保管し、ブラウザには渡さない。
#  現在は、テンポラリディレクトリにファイルを作って保管しているが、
#  DB wrapperができあがったら、そちらを利用する方式も考えよう。
#
#  同じユーザからの２つ以上の同時リクエストを仮定する場合は、どうしても
#  クリティカルなタイミングが残るが、実質問題にはならないだろう。
#  もとより、サーバ側はマルチプロセスで動作しているのだから、たとえ
#  セッションIDが同じでも、セッション変数の共通化はできないタイミングが残る。
#  これを解決させるには、こんな単純な実装では駄目で、OSレベルでのサポートも
#  必要だし、今回はこれでOKとする。


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

  # セッションID
  @@session_id = nil
  
  # セッション変数のHash
  @@session_var = {}

  # セッション変数のHashが更新されたかの確認用
  @@session_var_hash = nil

  # 保存ファイルオブジェクト
  @@session_file = nil

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
    @@session_id = Alone::get_cookie( :ALSESSID )

    #
    # すでにセッションIDが割り当て済みの場合
    #
    if /\A[a-zA-Z0-9]{32}\Z/ =~ @@session_id
      begin
        @@session_file = open( "#{AL_SESS_DIR}ALSESSID_#{@@session_id}", 'r+' )
        AlSession.load()
        return

      rescue
        # ファイルが何らかの理由により、存在しない。
        # よって、セッションID未割り当ての場合と同じ処理へ移行する。
      end
    end

    #
    # セッションID未割り当ての場合
    #
    retry_count = 0
    begin
      @@session_id = make_session_id()
      @@session_file = open( "#{AL_SESS_DIR}ALSESSID_#{@@session_id}",
                             File::RDWR|File::CREAT|File::EXCL )
      Alone::set_cookie( :ALSESSID, @@session_id, nil, '/' )

    rescue
      retry_count += 1
      if retry_count > 10
        puts "Can't create session file. Fix an AL_SESS_DIR parameter in al_config.rb file."
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
    # ファイルに、セッション変数を書き出す。
    # (note)
    #  ロック解除は、close()に任せること。
    if @@session_file
      if @@session_var.hash() != @@session_var_hash
        @@session_file.flock( File::LOCK_EX )
        @@session_file.seek( 0, IO::SEEK_SET )
        @@session_file.truncate( 0 )
        @@session_file.write( Marshal.dump( @@session_var ) )
      end
      @@session_file.close()
    end

    #
    # 古いセッション情報を消去するか判断
    # (note)
    # STRATEGY: マーカファイルを作っておき、その作成日付を元に、
    #           消去処理を動作させるか否かを判断する。
    #
    nowtime = Time.now
    begin
      mtime = File.mtime( File.join( AL_SESS_DIR, "ALSESS_TIMEOUT_MARKER" ) )
      return  if (nowtime - mtime) < (AL_SESS_TIMEOUT / 2)
    rescue
      # nothing to do
    end
    File.open( File.join( AL_SESS_DIR, "ALSESS_TIMEOUT_MARKER" ), 'w' ) {}

    #
    # 古いセッション情報ファイルを消去
    #
    Dir.glob( File.join( AL_SESS_DIR, "ALSESSID_*" ) ).each do |file|
      mtime = File.mtime( file )
      if (nowtime - mtime) > AL_SESS_TIMEOUT
        File.unlink( file ) rescue 0
      end
    end

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
    @@session_file.close()
    File.unlink( File.join( AL_SESS_DIR, "ALSESSID_#{@@session_id}" ) )

    #
    # 新しいセッションidおよびファイルを作る
    #
    retry_count = 0
    begin
      @@session_id = make_session_id()
      @@session_file = File.open( 
        File.join( AL_SESS_DIR, "ALSESSID_#{@@session_id}" ),
        File::RDWR|File::CREAT|File::EXCL )
      Alone::set_cookie( :ALSESSID, @@session_id, nil, '/' )

    rescue
      retry_count += 1
      if retry_count > 10
        raise "Can't create session file."
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
    File.unlink( File.join( AL_SESS_DIR, "ALSESSID_#{@@session_id}" ) )
    @@session_id = nil
  end


  ##
  # セッション変数の読み込み
  #@note
  # COMETなどで非常に長くセッションが続く場合に、ほかの接続から行われた
  # セッション変数の変更を反映したい場合にも使うことができる。
  # 自分が行った変更は破棄される。
  #
  def self.load()
    @@session_file.flock( File::LOCK_SH )
    @@session_file.seek( 0, IO::SEEK_SET )
    @@session_var = Marshal.load( @@session_file.read() ) rescue {}
    @@session_file.flock( File::LOCK_UN )
    @@session_var_hash = @@session_var.hash()
  end


  ##
  # セッション変数の選択的保存
  #@param [Array<Symbol>] key  保存対象
  #@note
  # COMETなどで非常に長くセッションが続く場合に、自分が行った変更を
  # 一旦コミットしたい場合に使うことができる。
  #
  def self.save( *keys )
    @@session_file.flock( File::LOCK_EX )
    @@session_file.seek( 0, IO::SEEK_SET )
    new_vars = Marshal.load( @@session_file.read() ) rescue {}
    
    keys.each { |key|
      new_vars[key.to_sym] = @@session_var[key.to_sym]
    }
    @@session_var = new_vars

    @@session_file.seek( 0, IO::SEEK_SET )
    @@session_file.truncate( 0 )
    @@session_file.write( Marshal.dump( @@session_var ) )
    @@session_file.fsync()
    @@session_file.flock( File::LOCK_UN )
    @@session_var_hash = @@session_var.hash()
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
