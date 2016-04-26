#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# データ永続化　ファイルによる永続化

require 'tempfile'
require 'al_persist'


##
# データ永続化 単純ファイル版
#
#@note
# データ本体は、Marshalによるエンコードを行っている。
# 識別のため、プライマリキーとして:idが自動的に付与される。
# 検索は使えない。並べ替えは使えない。
#
class AlPersistFile < AlPersist

  ##
  # ファクトリ
  #
  #@param [String] conn_info    ファイル名
  #@return [AlPersistFile]      オブジェクト
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
    super( nil, :id )
    @filename = fname
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
    return false  if ! @values[:id]
    id = "#{@values[:id]}\n"

    file = nil
    ret = false
    begin
      file = open( @filename, 'r' )
      file.flock( File::LOCK_SH )

      while (keys = file.gets) && (datas = file.gets)
        if keys == id
          @values = Marshal.load( Alone::decode_uri_component( datas ) )
          ret = true
          break
        end
      end
      file.close()
      
    rescue
      file.close()  if file
    end

    return ret
  end


  ##
  # データをファイルへ、新規保存する。
  #
  #@param  [Hash]       values プライマリキーを含む保存する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで、
  # 内部値を新規保存する。
  #
  def create( values = nil )
    @values = values  if values

    file = open( @filename, File::RDWR|File::CREAT )
    file.flock( File::LOCK_EX )

    id = ""
    while (keys = file.gets) && (datas = file.gets)
      id = keys
    end
    id = (id.chomp.to_i + 1).to_s
    @values[:id] = id
    file.puts( id )
    file.puts( Alone::encode_uri_component( Marshal.dump( @values ) ) )
    file.close()

    return true
  end


  ##
  # キーの合致するファイル内のデータを、更新する。
  #
  #@param  [Hash]       values プライマリキーを含む更新する値のHash
  #@return [Boolean]    成功／失敗
  #@note
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで更新する。
  #
  def update( values = nil )
    @values = values  if values
    return false  if ! @values[:id]
    id = "#{@values[:id]}\n"

    ret = false
    file = open( @filename, 'r' )
    file.flock( File::LOCK_SH )
    fout = Tempfile.new( "al-temp", File.dirname(@filename) )
    while (keys = file.gets) && (datas = file.gets)
      if keys == id
        fout.puts( id )
        fout.puts( Alone::encode_uri_component( Marshal.dump( @values ) ) )
        ret = true
      else
        fout.write( keys )
        fout.write( datas )
      end
    end
    file.close()
    File.rename( fout.path, @filename )
    fout.close()

    return ret
  end


  ##
  # キーの合致するファイル内のデータを、削除する。
  #
  #@param  [Hash]       values プライマリキーを含むHash
  #@return [Boolean]    成功／失敗
  #@note
  # valuesには、プライマリキー以外の値が含まれていてもよく、単に無視される。
  # 引数の指定があれば、その値を一旦内部値(@values)にしたうえで削除する。
  #
  def delete( values = nil )
    @values = values  if values
    return false  if ! @values[:id]
    id = "#{@values[:id]}\n"

    ret = false
    file = open( @filename, 'r' )
    file.flock( File::LOCK_SH )
    fout = Tempfile.new( "al-temp", File.dirname(@filename) )
    while (keys = file.gets) && (datas = file.gets)
      if keys == id
        ret = true
      else
        fout.write( keys )
        fout.write( datas )
      end
    end
    file.close()
    File.rename( fout.path, @filename )
    fout.close()

    return ret
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
    @values = values  if values
    if @values[:id]
      id = "#{@values[:id]}\n"
    else
      id = nil
    end

    ret = false
    new_id = ""
    file = open( @filename, 'r' )
    file.flock( File::LOCK_SH )
    fout = Tempfile.new( "al-temp", File.dirname(@filename) )
    while (keys = file.gets) && (datas = file.gets)
      new_id = keys
      fout.write( keys )
      if keys == id
        fout.puts( Alone::encode_uri_component( Marshal.dump( @values ) ) )
        ret = true
      else
        fout.write( datas )
      end
    end

    if ! ret
      id = (new_id.chomp.to_i + 1).to_s
      @values[:id] = id
      fout.puts( id )
      fout.puts( Alone::encode_uri_component( Marshal.dump( @values ) ) )
      ret = true
    end

    file.close()
    File.rename( fout.path, @filename )
    fout.close()

    return ret
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
    search( :limit=>nil, :offset=>nil )
  end


  ##
  # 登録データを選択的に読み込む。
  #
  #@param  [Hash]  param                検索パラメータ
  #@option param [Integer] :limit       最大取得数
  #@option param [Integer] :offset      オフセット
  #@return [Array<AlPersist>]           Persistオブジェクトの配列
  #@note
  # データ1件を1つのAlPersistオブジェクトとして配列で返す。
  # 一件もデータがない場合は、空の配列を返す。
  # read()と違って自分は何も変わらず、自分の複製を生産する。
  # RDB等と違って、選択パラメータは、limitとoffsetのみ。
  #
  def search( param = {} )
    #
    # limitとoffsetの調整
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

    total_rows = 0
    file = nil
    ret = []
    begin
      file = open( @filename, 'r' )
      file.flock( File::LOCK_SH )
      while (keys = file.gets) && (datas = file.gets)
        total_rows += 1

        if @search_condition[:limit]
          next  if ret.count >= @search_condition[:limit]
          if @search_condition[:offset]
            next  if total_rows <= @search_condition[:offset]
          end
        end

        t = self.dup
        t.values = Marshal.load( Alone::decode_uri_component( datas ) )
        ret << t
      end
      file.close()

    rescue
      file.close()  if file
    end

    @search_condition[:total_rows] = total_rows
    @search_condition[:num_rows] = ret.size
    @search_condition[:has_next_page] = (@search_condition[:offset].to_i + @search_condition[:num_rows]) < @search_condition[:total_rows]

    return ret
  end

end
