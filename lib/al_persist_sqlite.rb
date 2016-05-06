#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require 'al_persist_rdb'
require 'al_rdbw_sqlite'


##
# データ永続化 SQLite3版
#
class AlPersistSqlite < AlPersistRDB
  
  ##
  # RDBサーバとのコネクションをオープンする
  #
  #@param [String] conn_info    接続情報
  #@return [AlRdbw]             RDB wrapper オブジェクト
  #
  def self.connect( conn_info = nil )
    return AlRdbwSqlite.connect( conn_info )
  end

end



class AlRdbwSqlite
  # DB wrapperクラスへメソッド追加する
  
  ##
  # tableを指定して、Persistオブジェクトを生成
  #
  #@param  [String]  tname            テーブル名
  #@param  [Array<String,Symbol>,String,Symbol]  pkey   プライマリキー
  #@return [AlPersistSqlite]          データ永続化オブジェクト
  #
  def table( tname, pkey = nil )
    return AlPersistSqlite.new( self, tname, pkey )
  end


  ##
  # tableを指定して、Persistオブジェクトを生成 syntax sugar
  #@param  [String]  tname            テーブル名
  #@return [AlPersistSqlite]          データ永続化オブジェクト
  #
  def []( tname )
    return AlPersistSqlite.new( self, tname )
  end

end
