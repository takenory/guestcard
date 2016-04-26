#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# Tested by sqlite3-3.6.19 + sqlite3-ruby (1.3.1)
#  http://www.sqlite.org/
#  http://rubyforge.org/projects/sqlite-ruby

require 'sqlite3'
require 'al_rdbw'


##
# リレーショナルデータベースラッパー SQLite版
#
class AlRdbwSqlite < AlRdbw

  #@return [Object] connectメソッドが生成するオブジェクトのためのクラス (継承アトリビュート)
  @@suitable_dbms = self


  ##
  # RDBとのコネクションを開始する
  #
  #@todo
  # コネクションエラー時のエラー処理をどこでするかを明確化して実装しなければならない。
  # 下請けにするライブラリの都合などを鑑みて、全体統一を図る必要があるだろう。
  # それには、現在のSQLiteとPostgreSQLだけでは、サンプルが足りないように思う。
  #
  def open_connection()
    return false  if ! @conn_info

    @handle = SQLite3::Database.new( @conn_info )
    @handle.type_translation = true
    @handle.busy_timeout( 1000000 )
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
    get_handle().execute( sql, var )
    ret = { :cmdtuples=>handle.changes(), 
            :insert_id=>handle.last_insert_row_id() }
    return ret
  end
  alias exec execute


  ##
  # select文の発行ヘルパー
  #
  #@param  [String]      sql  SQL文
  #@param  [Array,Hash]  where_cond  where条件
  #@return [Array<Hash>] 結果の配列
  #@example
  #  where condition
  #   use Array
  #    select( "select * from t1 where id=?;", [2] )
  #   use Hash
  #    select( "select * from t1 _WHERE_;",
  #      { :id=>2, :age=>nil, "name like"=>"a%" } )
  #
  def select( sql, where_cond = nil )
    case where_cond
    when NilClass
      result = get_handle().prepare( sql ).execute()

    when Array
      result = get_handle().prepare( sql ).execute( where_cond )

    when Hash
      s = sql.split( '_WHERE_' )
      raise "SQL error in select()"  if s.size != 2
      (where, val) = make_where_condition( where_cond )
      result = get_handle().prepare( "#{s[0]} where #{where} #{s[1]}" ).execute( val )

    when String
      sql.sub!( '_WHERE_', "where #{where_cond}" )
      result = get_handle().prepare( sql ).execute()

    else
      raise "where_cond error in select()"
    end

    # アトリビュート用キーの準備
    keys = []
    result.columns.each { |k| keys << k.to_sym }

    # 戻り値用Hashの生成
    ret = []
    result.each do |r|
      a = {}
      keys.each do |k|
        v = r.shift
        v.force_encoding( AL_CHARSET ) if v.respond_to?('force_encoding')
        a[k] = v
      end
      ret << a
    end
    result.close

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
    values.each do |k,v|
      col << "#{k},"
      plh << "?,"
      case v
      when Array
        val << v.join( ',' )
      when String, Fixnum, NilClass
        val << v
      else
        val << v.to_s
      end
    end
    col.chop!
    plh.chop!

    sql = "insert into #{table} (#{col}) values (#{plh});"
    handle = get_handle()
    handle.execute( sql, val )

    return { :cmdtuples=>handle.changes(), :insert_id=>handle.last_insert_row_id() }
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
    val = []
    values.each do |k,v|
      columns << "#{k}=?,"
      case v
      when Array
        val << v.join( ',' )
      when String, Fixnum, NilClass
        val << v
      else
        val << v.to_s
      end
    end
    columns.chop!

    (where, wval) = make_where_condition( where_cond )

    sql = "update #{table} set #{columns} where #{where};"
    get_handle().execute( sql, val + wval )

    return { :cmdtuples=>handle.changes() }
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
    get_handle().execute( sql, wval )

    return { :cmdtuples=>handle.changes() }
  end


  ##
  # トランザクション開始
  #
  #@return [Boolean]    成否
  #
  def transaction()
    return false  if @flag_transaction
    get_handle().execute( "begin transaction;" )
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
    get_handle().execute( "commit transaction;" )
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
    get_handle().execute( "rollback transaction;" )
    @flag_transaction = false
    return true
  end

end
