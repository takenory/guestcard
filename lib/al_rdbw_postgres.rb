#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# Tested by ruby-pg-0.8.0

require 'time'
require 'pg'
require 'al_rdbw'


##
# リレーショナルデータベースラッパー PostgreSQL版
#
class AlRdbwPostgres < AlRdbw

  #@return [Object] connectメソッドが生成するオブジェクトのためのクラス (継承アトリビュート)
  @@suitable_dbms = self

  #@return [Object] クエリ実行結果
  attr_reader :result


  ##
  # RDBサーバとのコネクションを開始する
  #
  #@todo
  # コネクションエラー時のエラー処理をどこでするかを明確化して実装しなければならない。
  # 下請けにするライブラリの都合などを鑑みて、全体統一を図る必要があるだろう。
  # それには、現在のSQLiteとPostgreSQLだけでは、サンプルが足りないように思う。
  #
  def open_connection()
    return false  if ! @conn_info

    @handle = PGconn.connect( @conn_info )
    @handle.set_client_encoding( AL_CHARSET.to_s )
    @conn_info = nil
  end


  ##
  # 任意SQLの実行
  #
  #@param  [String] sql  SQL文
  #@param  [Array]  var  パラメータクエリ用変数
  #@return [Hash] 結果
  #@note
  # アクションクエリの実行用。selectは、select()メソッドを使う。
  #
  def execute( sql, var = [] )
    @result = get_handle().exec( sql, var )
    ret = { :cmdtuples=>@result.cmdtuples }
    @result.clear()
    return ret
  end
  alias exec execute


  ##
  # select文の発行ヘルパー
  #
  #@param  [String]      sql  SQL文
  #@param  [Array,Hash,String]  where_cond  where条件
  #@return [Array<Hash>] 結果の配列
  #@example
  #  where condition
  #   use Array
  #    select( "select * from t1 where id=$1;", [2] )
  #   use Hash
  #    select( "select * from t1 _WHERE_;",
  #      { :id=>2, :age=>nil, "name like"=>"a%" } )
  #
  def select( sql, where_cond = nil )
    case where_cond
    when NilClass
      @result = get_handle().exec( sql )
      
    when Array
      @result = get_handle().exec( sql, where_cond )

    when Hash
      s = sql.split( '_WHERE_' )
      raise "SQL error in select()"  if s.size != 2
      (where, val) = make_where_condition( where_cond )
      @result = get_handle().exec( "#{s[0]} where #{where} #{s[1]}", val )

    when String
      sql.sub!( '_WHERE_', "where #{where_cond}" )
      @result = get_handle().exec( sql )

    else
      raise "where_cond error in select()"
    end

    if @result.result_status != PGresult::PGRES_TUPLES_OK
      raise "SQL error. result is not TUPLES_OK."
    end

    #
    # データの取り出しとデータタイプの変換
    #  number means PostgreSQL's Object ID.
    #  see src/include/catalog/pg_type.h
    #
    ret = []
    @result.each do |r|
      i = 0
      a = {}
      r.each do |k,v|
        if v != nil
          case @result.ftype( i )
          when 16               # bool
            v = (v == "t") ? "true" : "false"

          when 20,21,23, 26     # int, OID
            v = v.to_i

          when 25,1042,1043     # text, char, varchar
            v.force_encoding( AL_CHARSET )

          when 700,701          # float
            v = v.to_f

          when 1082,1083,1114,1184   # date,time,timestamp
            v = Time.parse( v )

          end
        end

        a[k.to_sym] = v
        i += 1
      end
      ret << a
    end
    @result.clear()

    return ret
  end


  ##
  # insert文の発行ヘルパー
  #
  #@param [String]  table     テーブル名
  #@param [Hash]    values    insertする値のhash
  #@return [Hash]             結果のHash
  #
  def insert( table, values )
    col = ""
    plh = ""
    val = []
    cnt = 1
    values.each do |k,v|
      col << "#{k},"
      plh << "$#{cnt},"
      cnt += 1
      if v.class == Array
        val << v.join( ',' )
      else
        val << v
      end
    end
    col.chop!
    plh.chop!

    sql = "insert into #{table} (#{col}) values (#{plh});"
    @result = get_handle().exec( sql, val )
    ret = { :cmdtuples=>@result.cmdtuples }

    @result.clear()
    return ret
  end


  ##
  # update文の発行ヘルパー
  #
  #@param [String]  table     テーブル名
  #@param [Hash]    values    updateする値のhash
  #@param [Hash]  where_cond  where条件
  #@return [Hash]             結果のHash
  #
  def update( table, values, where_cond )
    columns = ""
    cnt = 1
    val = []
    values.each do |k,v|
      columns << "#{k}=$#{cnt},"
      cnt += 1
      if v.class == Array
        val << v.join( ',' )
      else
        val << v
      end
    end
    columns.chop!

    (where, wval) = make_where_condition( where_cond, cnt )

    sql = "update #{table} set #{columns} where #{where};"
    @result = get_handle().exec( sql, val + wval )
    ret = { :cmdtuples=>@result.cmdtuples }

    @result.clear()
    return ret
  end


  ##
  # delete文の発行ヘルパー
  #
  #@param [String]  table     テーブル名
  #@param [Hash]  where_cond  where条件
  #@return [Hash]             結果のHash
  #
  def delete( table, where_cond )
    (where, wval) = make_where_condition( where_cond )
    sql = "delete from #{table} where #{where};"
    @result = get_handle().exec( sql, wval )
    ret = { :cmdtuples=>@result.cmdtuples }

    @result.clear()
    return ret
  end


  ##
  # トランザクション開始
  #
  #@return [Boolean]    成否
  #
  def transaction()
    return false  if @flag_transaction
    @result = get_handle().exec( "begin transaction;" )
    @result.clear()
    return @flag_transaction = true
  end


  ##
  # トランザクションコミット
  #
  #@return [Boolean]    成否
  #@todo
  # 実装中。トランザクションがSQLレベルで失敗する条件をテストして返り値に反映する
  #
  def commit()
    return false  if ! @flag_transaction
    @result = get_handle().exec( "commit transaction;" )
    @result.clear()
    @flag_transaction = false
    return true
  end


  ##
  # トランザクションロールバック
  #
  #@return [Boolean]    成否
  #
  def rollback()
    return false  if ! @flag_transaction
    @result = get_handle().exec( "rollback transaction;" )
    @result.clear()
    @flag_transaction = false
    return true
  end


  private
  ##
  # where 条件がHashで与えられたときの解析
  # 複合条件は、andのみ。
  #
  def make_where_condition( where_cond, cnt = 1 )
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
        whe << "=$#{cnt}"
      else
        whe << " $#{cnt}"
      end
      val << v
      cnt += 1
    end
    whe = "1=1" if ! whe

    return whe, val
  end

end
