#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# sh設定ファイルへのAlPersistインターフェース

require 'tempfile'
require 'al_persist'


##
# sh設定ファイルへのAlPersistインターフェース
#
#@note
# 擬似的にAlPersistのインターフェースを真似ているが、
# データの性質は違うので注意する。
# このクラスでは、イメージ的にはRDBでいうところの
# 横持ち構造になっていて、1行のみデータが存在する。
#
class AlPersistSh < AlPersist

  REX_DATA = /\A\s*(\w+)=["'](.*)["']/

  ##
  # ファクトリ
  #
  #@param [String] conn_info    ファイル名
  #@return [AlPersistSh]      オブジェクト
  #
  def self.connect( conn_info = nil )
    return self.new( conn_info )
  end


  #@return [String]     保存ファイル名
  attr_reader :filename

  ##
  # constructor
  #
  #@param [String] fname  ファイルネーム
  #
  def initialize( fname )
    super( nil, nil )
    @filename = fname
  end


  ##
  # データを読み込み、内部(@values) に保持する。
  #
  #@param  [Hash]       values  ダミー
  #@return [Boolean]    成功／失敗
  #@note
  # ファイルが存在しなくても、成功とする。
  #
  def read( values = nil )
    @values = {}
    begin
      file = open( @filename, 'r' )
    rescue Errno::ENOENT
      return true
    end

    while text = file.gets
      next if REX_DATA !~ text
      k = $1
      v = $2.gsub(/\\(u\{[\da-fA-F]+\}|x[\da-fA-F]{2}|\d{3}|[a-zA-Z\\"'])/) {
        eval( %Q("\\#{$1}") )
      }
      @values[k.to_sym] = v
    end
    file.close()

    return true
  end


  ##
  # 削除
  #
  #@param  [Hash]       values  消す項目のhash
  #@return [Boolean]    成功／失敗
  #@note
  # ファイル中の、キーの合致するデータを削除する。
  # 他のPersistクラスと、動作が違うので注意する。
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで削除する。
  # 消すための処理は、keyが合致することだけをみていて、値は必要ではない。
  # ファイルが存在しなかったり、項目が存在せずに値を消すことができなくても成功とする。
  #
  def delete( values = nil )
    @values = values  if values

    begin
      file = open( @filename, 'r' )
    rescue Errno::ENOENT
      return true
    end
    fout = Tempfile.new( "al-temp", File.dirname(@filename) )

    while text = file.gets
      if REX_DATA =~ text
        k = $1
        next if @values.has_key?( k )
        next if @values.has_key?( k.to_sym )
      end
      fout.write( text )
    end

    file.close()
    File.rename( fout.path, @filename )
    fout.close()

    return true
  end


  ##
  # 新規登録
  #
  #@param  [Hash]       values 保存する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで登録する。
  # キーの合致するデータがあれば更新し、なければ新規登録する。
  #
  def create( values = nil )
    entry_main( :create, values )
  end
  alias entry create


  ##
  # 更新
  #
  #@param  [Hash]       values 保存する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで登録する。
  #
  def update( values = nil )
    entry_main( :update, values )
  end


  ##
  # データを読み込む。
  #
  #@param  [Hash]  param                検索パラメータ（ダミー）
  #@return [Array<AlPersist>]           Persistオブジェクトの配列
  #@note
  # 他のPersistクラスとの互換性の為に定義する。
  #
  def search( param = {} )
    obj = self.dup()
    obj.read()
    if obj.values.empty?
      @search_condition[:total_rows] = 0
      @search_condition[:num_rows] = 0
      return []
    else
      @search_condition[:total_rows] = 1
      @search_condition[:num_rows] = 1
      return [obj]
    end
  end
  alias all search


  private
  ##
  # create,update,entry のメイン処理
  #
  #@param  [Symbol]     wflag  動作フラグ {:create,:update,:entry}
  #@param  [Hash]       values 保存する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで登録する。
  #
  def entry_main( wflag, values )
    @values = values  if values
    ret = true

    begin
      file = open( @filename, 'r' )
    rescue Errno::ENOENT
      file = open( @filename, File::RDWR|File::CREAT )
    end
    fout = Tempfile.new( "al-temp", File.dirname(@filename) )

    # データファイルのコメント行などを壊さないように
    # 一行ずつ処理する。
    val = @values.dup
    while text = file.gets
      if REX_DATA =~ text
        k = $1
        if val.has_key?( k.to_sym )
          text = "#{k}=#{val[k.to_sym].to_s.inspect}\n"
          val.delete( k.to_sym )
        elsif val.has_key?( k )
          text = "#{k}=#{val[k].to_s.inspect}\n"
          val.delete( k )
        end
      end
      fout.write( text )
    end

    case wflag
    when :create, :entry
      val.each { |k,v| fout.write( "#{k}=#{v.to_s.inspect}\n" ) }
    when :update
      ret = false  if ! val.empty?
    end

    file.close()
    File.rename( fout.path, @filename )
    fout.close()

    return ret
  end

end
