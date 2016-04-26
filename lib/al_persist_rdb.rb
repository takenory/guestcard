#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require 'al_persist'


##
# データ永続化 RDB共通クラス
#
class AlPersistRDB < AlPersist

  #@return [String]  テーブル名
  attr_reader :table

  #@return [String]  検索フィールド名
  attr_accessor :column


  ##
  # constructor
  #
  #@param [AlRdbw] base         使用する RDB wrapper オブジェクト
  #@param [String] tname        テーブル名
  #@param [Array<String,Symbol>,String,Symbol]  keys   プライマリキー
  #
  def initialize( base, tname, keys = nil )
    super( base, keys )
    @table = tname
    @column = "*"
  end


  ##
  # キーを指定してデータを読み込み、内部(@values) に保持する。
  #
  #@param  [Hash]       values  プライマリキーを含むHash
  #@return [Boolean]    成功／失敗
  #@note
  # valuesには、プライマリキー以外の値が含まれていてもよく、単に無視される。
  #
  def read( values = nil )
    @values = values  if values
    @search_condition = {}
    return false  if @values.empty?

    #
    # exclude keys
    #
    val = {}
    if ! @pkeys.empty?
      @pkeys.each do |k|
        return false  if ! @values.key?( k )
        val[k] = @values[k]
      end
    else
      @values.each do |k,v|
        val[k.to_sym] = v
      end
    end

    #
    # run sql
    #
    rows = @persist_base.select( "select #{@column} from #{@table} _WHERE_;", val )
    return false  if rows.empty?

    @values = rows[0]
    return true
  end


  ##
  # データをRDBへ、新規保存する。
  #
  #@param  [Hash]       values プライマリキーを含む保存する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで、
  # 内部値を新規保存する。
  #
  def create( values = nil )
    @values = values  if values

    @result = @persist_base.insert( @table, @values )
    return @result[:cmdtuples] == 1 ? true : false
  end


  ##
  # キーの合致するRDB内のデータを、更新する。
  #
  #@param  [Hash]       values プライマリキーを含む更新する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで更新する。
  #
  def update( values = nil )
    @values = values  if values
    return false  if @pkeys.empty?

    value_hash = @values.dup
    where_hash = {}

    # exclude key
    @pkeys.each do |k|
      raise "No key included in value. #{k}"  if ! value_hash[k]
      where_hash[k] = value_hash[k]
      value_hash.delete( k )
    end

    @result = @persist_base.update( @table, value_hash, where_hash )
    return @result[:cmdtuples] == 1 ? true : false
  end


  ##
  # キーの合致するRDB内のデータを、削除する。
  #
  #@param  [Hash]       values プライマリキーを含むHash
  #@return [Boolean]    成功／失敗
  #@note
  # valuesには、プライマリキー以外の値が含まれていてもよく、単に無視される。
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで削除する。
  #
  def delete( values = nil )
    @values = values  if values

    if @pkeys.empty?
      @result = @persist_base.delete( @table, @values )

    else
      where_hash = {}

      # exclude keys
      @pkeys.each do |k|
        raise "No key included in value. #{k}"  if ! @values[k]
        where_hash[k] = @values[k]
      end

      @result = @persist_base.delete( @table, where_hash )
    end

    return @result[:cmdtuples] == 1 ? true : false
  end


  ##
  # キーの合致するデータがあれば更新し、なければ新規登録する。
  #
  #@param  [Hash]       values プライマリキーを含む保存する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで登録する。
  #
  def entry( values = nil )
    delete( values )
    create()
  end


  ##
  # 登録データをすべて読み込む。
  #
  #@return [Array<AlPersist>]     AlPersistオブジェクトの配列
  #@note
  # データ1件を1つのAlPersistオブジェクトとして配列で返す。
  # 一件もデータがない場合は、空の配列を返す。
  # read()と違って自分は何も変わらず、自分の複製を生産する。
  #
  def all()
    rows = @persist_base.select( "select #{@column} from #{@table};" )

    ret = []
    rows.each do |row|
      a = self.dup
      a.values = row
      ret << a
    end

    @search_condition = { :total_rows=>ret.size, :num_rows=>ret.size }
    return ret
  end


  ##
  # 登録データを選択的に読み込む。
  #
  #@param  [Hash]  param                検索パラメータ
  #@option param [Hash]  :where         検索条件のハッシュ
  #@option param [Hash,Array,String] :order_by  並べ替え順
  #@option param [Integer] :limit       最大取得数
  #@option param [Integer] :offset      オフセット
  #@option param [Boolean] :total_rows  全件取得するか？
  #@option param [Integer] :total_rows  全件数のキャッシュ
  #@return [Array<AlPersist>]           Persistオブジェクトの配列
  #@see AlRdbwSqlite#select
  #@note
  # データ1件を1つのAlPersistオブジェクトとして配列で返す。
  # 一件もデータがない場合は、空の配列を返す。
  # read()と違って自分は何も変わらず、自分の複製を生産する。
  # :total_rowsがtrueの時は、全件数も取得する。
  # :total_rowsが数値の時は、それを全件数の値として採用する。
  #
  def search( param = {} )
    return search_common( param,
        "select #{@column} from #{@table} #{param[:where] ? '_WHERE_' : ''}",
        "select count(*) as numrows from #{@table} #{param[:where] ? '_WHERE_' : ''};" )
  end


  ##
  # selectを直接発行して登録データを選択的に読み込む。
  #
  #@param  [String]     tuple           取得するタプル名
  #@param  [String]     sql_part        from以降（from句含む）
  #@param  [Hash]  param                その他パラメータ
  #@option param [Hash]  :where         検索条件のハッシュ
  #@option param [Array] :where         パラメータクエリためのパラメータ
  #@option param [Hash,Array,String] :order_by  並べ替え順
  #@option param [Integer] :limit       最大取得数
  #@option param [Integer] :offset      オフセット
  #@option param [Boolean] :total_rows  全件取得するか？
  #@option param [Integer] :total_rows  全件数のキャッシュ
  #@return [Array<AlPersist>]           Persistオブジェクトの配列
  #@example
  #  datas = persist.select( "t1.*, t2.note",
  #     "from t1 inner join t2 using(id) where d=CURRENT_DATE"
  #     :order_by=>"create_date desc", :limit=>limit, :offset=>offset,
  #     :total_rows=>total_rows )
  #
  def select( tuple, sql_part, param = {} )
    return search_common( param,
                "select #{tuple} #{sql_part}",
                "select count(*) as numrows #{sql_part};" )
  end


  private
  ##
  # 検索共通部
  #
  def search_common( param, sql, sql_count )
    #
    # SQL order by
    #
    sql_part = ""
    @search_condition[:order_by] = param[:order_by]  if param[:order_by]
    case @search_condition[:order_by]
    when Array
      flag_1st = true
      @search_condition[:order_by].each do |k|
        sql_part << (flag_1st ? " order by #{k}" : ",#{k}")
        flag_1st = false
      end

    when Hash
      flag_1st = true
      @search_condition[:order_by].each do |k,v|
        next if /^asc|desc$/i !~ v
        sql_part << (flag_1st ? " order by #{k} #{v}" : ",#{k} #{v}")
        flag_1st = false
      end

    when String
      sql_part << " order by #{@search_condition[:order_by]}"
    end

    #
    # SQL limit, offset
    #
    if param[:limit]
      limit = param[:limit].to_i
      limit = 1  if limit < 1
      @search_condition[:limit] = limit
    end
    if param[:offset]
      offset = param[:offset].to_i
      offset = 0  if offset < 0
      @search_condition[:offset] = offset
    end
    if @search_condition[:limit]
      sql_part << " limit #{@search_condition[:limit] + 1}"
      if @search_condition[:offset]
        sql_part << " offset #{@search_condition[:offset]}"
      end
    end

    #
    # SQL where
    #
    @search_condition[:where] = param[:where]  if param[:where]

    #
    # 件数取得
    #
    case param[:total_rows]
    when TrueClass
      rows = @persist_base.select( sql_count, @search_condition[:where] )
      @search_condition[:total_rows] = rows[0][:numrows].to_i

    when Fixnum
      @search_condition[:total_rows] = param[:total_rows]
    end

    #
    # 実データ取得
    #
    rows = @persist_base.select( "#{sql} #{sql_part};", @search_condition[:where] )

    #
    # 次ページがあるか確認・調整
    #
    @search_condition[:has_next_page] = @search_condition[:limit] && @search_condition[:limit] < rows.count
    rows.pop  if @search_condition[:has_next_page]
    @search_condition[:num_rows] = rows.count

    #
    # 結果配列の作成
    #
    ret = []
    rows.each do |row|
      a = self.dup
      a.values = row
      ret << a
    end

    return ret
  end

end
