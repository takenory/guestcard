#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# MySQL binding.
#  using "MySQL/Ruby"
#   http://rubyforge.org/frs/?group_id=4550

require 'mysql'
require 'al_rdbw'


##
# リレーショナルデータベースラッパー MySQL版
#
class AlRdbwMysql < AlRdbw

  #@return [Object] connectメソッドが生成するオブジェクトのためのクラス (継承アトリビュート)
  @@suitable_dbms = self


  ##
  # RDBサーバとのコネクションを開始する
  #
  def open_connection()
    return false  if ! @conn_info

#    @handle = Mysql::init()
#    @handle.options( Mysql::SET_CHARSET_NAME, "utf8" )  # can't use  AL_CHARSET. what to do?
#    @handle.connect( @conn_info[:host], @conn_info[:user],
#       @conn_info[:passwd], @conn_info[:db], @conn_info[:port], 
#       @conn_info[:sock], @conn_info[:flag] )

    @handle = Mysql::connect( @conn_info[:host], @conn_info[:user], 
        @conn_info[:passwd], @conn_info[:db], @conn_info[:port], 
        @conn_info[:sock], @conn_info[:flag] )
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
    # MySQLでは、"lock tables" 等は、query()でしか実行できない。
    begin
      stmt = get_handle().prepare( sql )
    rescue Mysql::Error => ex
      raise ex  if ex.errno != Mysql::Error::ER_UNSUPPORTED_PS
      raise ex  if ! var.empty?
      get_handle().query( sql )
      return {}
    end

    stmt.execute( *var )
    ret = { :cmdtuples=>stmt.affected_rows(), :insert_id=>stmt.insert_id() }
    stmt.close()
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
  #  use Array
  #   select( "select * from t1 where id=?;", [2] )
  #  use Hash
  #   select( "select * from t1 _WHERE_;",
  #     { :id=>2, :age=>nil, "name like"=>"a%" } )
  #
  def select( sql, where_cond = nil )
    case where_cond
    when NilClass
      stmt = get_handle().prepare( sql )
      stmt.execute()
      
    when Array
      stmt = get_handle().prepare( sql )
      stmt.execute( *where_cond )

    when Hash
      s = sql.split( '_WHERE_' )
      raise "SQL error in select()"  if s.size != 2
      (where, val) = make_where_condition( where_cond )
      stmt = get_handle().prepare( "#{s[0]} where #{where} #{s[1]}" )
      stmt.execute( *val )

    when String
      sql.sub!( '_WHERE_', "where #{where_cond}" )
      stmt = get_handle().prepare( sql )
      stmt.execute()

    else
      raise "where_cond error in select()"
    end

    #
    # データの取り出しとデータタイプの変換
    #  TODO: if type is bool?
    #
    ret = []
    fields = stmt.result_metadata().fetch_fields()

    stmt.each do |datas|
      r = {}
      datas.each_with_index do |d,i|
        case d
        when Mysql::Time
          case fields[i].type
          when Mysql::Field::TYPE_TIME
            r[ fields[i].name.to_sym ] = Time.local( 1, 1, 1, d.hour, d.minute, d.second )

          when Mysql::Field::TYPE_DATE
            r[ fields[i].name.to_sym ] = (d.year == 0) ? nil : Time.local( d.year, d.month, d.day, 0, 0, 0 )

          when Mysql::Field::TYPE_TIMESTAMP, Mysql::Field::TYPE_DATETIME
            r[ fields[i].name.to_sym ] = (d.year == 0) ? nil : Time.local( d.year, d.month, d.day, d.hour, d.minute, d.second )
          end

        when String
          d.force_encoding( AL_CHARSET )
          r[ fields[i].name.to_sym ] = d
        else
          r[ fields[i].name.to_sym ] = d
        end
      end
      ret << r
    end

    stmt.close()
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
      if v.class == Array
        val << v.join( ',' )
      else
        val << v
      end
    end
    col.chop!
    plh.chop!

    sql = "insert into #{table} (#{col}) values (#{plh});"
    stmt = get_handle().prepare( sql )
    stmt.execute( *val )
    ret = { :cmdtuples=>stmt.affected_rows(), :insert_id=>stmt.insert_id() }
    stmt.close()
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
    val = []
    values.each do |k,v|
      columns << "#{k}=?,"
      if v.class == Array
        val << v.join( ',' )
      else
        val << v
      end
    end
    columns.chop!

    (where, wval) = make_where_condition( where_cond )
    sql = "update #{table} set #{columns} where #{where};"
    val += wval

    stmt = get_handle().prepare( sql )
    stmt.execute( *val )
    ret = { :cmdtuples=>stmt.affected_rows() }
    stmt.close()
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

    stmt = get_handle().prepare( sql )
    stmt.execute( *wval )
    ret = { :cmdtuples=>stmt.affected_rows() }
    stmt.close()
    return ret
  end


  ##
  # トランザクション開始
  #
  #@return [Boolean]    成否
  #
  def transaction()
    return false  if @flag_transaction
    get_handle().query( "begin;" )
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
    get_handle().query( "commit;" )
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
    get_handle().query( "rollback;" )
    @flag_transaction = false
    return true
  end

end
