#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2013 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require "tempfile"
require "al_worker_ipc"

##
# デバッグサーバ
#
module AlWorker::Debug

  ##
  # デバッグ用IPCソケット、メソッド一式組み込み
  #
  def self.run( me )
    AlWorker.__send__( :include, AlWorker::Debug )
    @@ipcd = AlWorker::Ipc.new( File.join( me.workdir, me.name ) + ".debug" )
    @@ipcd.cb_prefix = "ipcd"
    @@ipcd.run( me )
  end


  ##
  # quitコマンドの処理
  #
  def ipcd_a_quit( sock, req )
    reply( sock, 200, "OK quit." )
    return false
  end


  ##
  # terminateコマンドの処理
  #
  def ipcd_a_terminate( sock, req )
    reply( sock, 200, "OK program terminate." )
    exit( 0 )
    return true
  end


  ##
  # インスタンス変数　一覧
  #
  def ipcd_a_list_variables( sock, req )
    reply( sock, 200, "OK", instance_variables.to_json )
  end
  alias ipcd_a_list_variable ipcd_a_list_variables


  ##
  # インスタンス変数　値取得
  #
  #@note
  # (IPC command)
  #  get_variable @var
  #
  def ipcd_a_get_variable( sock, param )
    reply( sock, 200, "OK", instance_variable_get( param[""] ).to_json )
  rescue =>ex
    reply( sock, 400, "Bad Request. #{ex.message}" )
  end


  ##
  # インスタンス変数　値設定
  # (TODO)
  # JSON object でデータを渡して複数の変数を一度にセット。 無くても良いかも。
  # (IDEA)
  # set_variable @変数名 = JSONデータ
  # 値の自由度はOK。
  # 変数名に対する解析をどうする？ ex) @var[3], @var["key"]
  # evalは、使いたくない。
  #
  #@note
  # (IPC command)
  #  set_variable @var=string
  #  set_variable @var[3]=string        # 未実装（文字列しか入れられない）
  #  set_variable @var["key"]=string    # 未実装
  #  set_variable {"@var":"any data"}
  #
  def ipcd_a_set_variables( sock, param )
    raise "Empty parameter."  if param.empty?

    if param[""]
      (k,v) = param[""].split( "=", 2 )
      raise "Parameter error."  if k == "" || v == nil || v == ""
      param = { k => v }
    end
      
    param.each do |k,v|
      instance_variable_set( k, v )
    end
    reply( sock, 200, "OK" )

  rescue =>ex
    reply( sock, 400, "Bad Request. #{ex.message}" )
  end
  alias ipcd_a_set_variable ipcd_a_set_variables


  ##
  # インスタンス変数　消去
  #
  def ipcd_a_delete_variable( sock, param )
    remove_instance_variable( param[""] )
    reply( sock, 200, "OK" )

  rescue =>ex
    reply( sock, 400, "Bad Request. #{ex.message}" )
  end


  ##
  # メソッド一覧
  #
  def ipcd_a_list_methods( sock, param )
    methods = self.public_methods - Object.public_methods - AlWorker::Debug.public_instance_methods
    reply( sock, 200, "OK", methods.to_json )
  end
  alias ipcd_a_list_method ipcd_a_list_methods


  ##
  # メソッド呼び出し
  #
  # (IPC)
  # call function( args,... )    args by json array.
  # call @me.method( args,... )
  #
  def ipcd_a_call( sock, param )
    param = param[""]
    raise "please specify method."  if param == nil || param == ""
    if /^((@\w+)\.)?(\w+)\(?(.*)/ !~ param
      raise "parameter error"
    end
    obj,method,param = $2,$3,$4.strip
    param.chop!  if param[-1] == ")"
    param = JSON.parse( "[ #{param} ]" )

    if obj
      ret = instance_variable_get( obj ).__send__( method, *param )
    else
      ret = __send__( method, *param )
    end
    reply( sock, 200, "OK", ret.to_json )

  rescue =>ex
    reply( sock, 400, "Bad Request. #{ex.message}" )
  end


  ##
  # 動作（常駐）しているプログラムにパッチをあてる
  #
  def ipcd_a_patch( sock, param )
    reply( sock, 100, "OK Let's go. Terminate ##END##" )
    file = Tempfile.new( "al_patch." )
    while txt = sock.gets
      break if txt.start_with?( "##END##" )
      file.puts txt
    end
    file.flush
    load( file.path )
    file.close!
    reply( sock, 200, "OK" )

  rescue =>ex
    reply( sock, 400, "Bad Request. #{ex.message}" )
  end


  ##
  # Rubyスクリプトの評価
  #
  def ipcd_a_eval( sock, param )
    ret = eval( param[""] )
    reply( sock, 200, "OK", ret )

  rescue =>ex
    reply( sock, 400, "Bad Request. #{ex.message}" )
  end


end
