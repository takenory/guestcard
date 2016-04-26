#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#


##
# リレーショナルデータベースラッパー スーパクラス
#
class AlRdbw

  #@return [Hash<AlRdbw>] Rdbwオブジェクトのハッシュ
  @@rdbw_objects = {}

  #@return [Object] デフォルトRdbwオブジェクト
  @@default_rdbw_object = nil

  #@return [Object] connectメソッドが生成するオブジェクトのためのクラス
  @@suitable_dbms = self

  #@return [String]  接続情報
  attr_reader :conn_info

  #@return [Object] データベースハンドル
  attr_reader :handle
  
  #@return [Boolean] トランザクション中かを示すフラグ
  attr_reader :flag_transaction


  ##
  # DB wrapper オブジェクトを得る。
  #
  #@param [String] conn_info  接続情報
  #@return [AlRdbw]     DBWrapperオブジェクト
  #@note
  # 名前とは裏腹に、DBSとの接続は開始しない。
  # 接続は、オブジェクトに対しopen_connection()メソッドで意識的に行うか、
  # あるいは、ヘルパーメソッドを使ったときに自動的に行われる。
  #
  def self.connect( conn_info = nil )
    # 既に対象の接続オブジェクトがあれば、それを返す。
    obj = conn_info ? @@rdbw_objects[ conn_info.hash ] : @@default_rdbw_object
    return obj  if obj

    # オブジェクトの生成と保存
    obj = ((self == AlRdbw) ? @@suitable_dbms : self).new( conn_info )
    @@default_rdbw_object ||= obj
    @@rdbw_objects[ conn_info.hash ] = obj
    return obj
  end


  ##
  # constractor
  #
  #@note
  # ユーザプログラムからは直接使わない。
  # オブジェクトの生成は、connect()メソッドを使って行う。
  #
  def initialize( conn_info )
    # AlRdbwは、バーチャルクラス扱いなので生成をランタイムエラーにしておく。
    raise "Need connect by subclass." if self.class == AlRdbw
    raise "Connection is missing. (No argument.)"  if ! conn_info

    @conn_info = conn_info
    @handle = nil
    @flag_transaction = false
  end


  ##
  # コネクションクローズ
  #
  def close()
    @handle.close() if @handle
    @handle = nil
    @flag_transaction = false
  end


  ##
  # オブジェクト破棄
  #@note
  # コネクションをクローズし、オブジェクト配列から削除を行う。
  #
  def purge()
    if @@default_rdbw_object == self
      @@default_rdbw_object = nil
    end
    @@rdbw_objects.delete_if { |k,v| v == self }
    close()
  end


  ##
  # RDBSとの接続ハンドルを得る
  #
  #@return [Object] handle
  #@note
  # 接続がまだ行われていなければ、自動的に接続を開始する。
  #
  def get_handle()
    if ! @handle
      open_connection()
    end
    return @handle
  end


  ##
  # トランザクション中か？
  #
  #@return [Boolean]    はい／いいえ
  #
  def transaction_active?()
    return @flag_transaction
  end


  private
  ##
  # where 条件がHashで与えられたときの解析
  # 複合条件は、andのみ。
  #
  def make_where_condition( where_cond )
    whe = nil
    val = []

    where_cond.each do |k,v|
      if whe
        whe << " and #{k}"
      else
        whe = "#{k}"
      end

      if v == nil
        if k.class == Symbol
          whe << " is null"
        end
        next
      end

      if k.class == Symbol    # symbolの時は、=で比較するルール
        whe << "=?"
      else
        whe << " ?"
      end
      val << v
    end
    whe = "1=1" if ! whe

    return whe, val
  end

end
