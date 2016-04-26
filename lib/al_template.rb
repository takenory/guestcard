#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# テンプレートマネージャ
# (note)
# なるべくobjectを生成しなくても仕事ができるように実装してみた。
# そのため、少し冗長に感じる部分もある。
# @trimを Erubisから引き継いでいるが、キャッシュにまで反映させていないので、
# 混ぜると誤動作するが、実害が無いと思うので、サポートしない。

##
# テンプレートマネージャ
#
class AlTemplate

  CACHE_SIGNATURE = "AL TEMPLATE CACHE. Version 1.00"


  ##
  # テンプレートファイルを適用し、レンダリングし、表示する。
  #
  #@param  [String]  filename   ファイル名
  #@param  [Object,Binding] ctxt     実行コンテキスト
  #@note
  # al_config中に指示があれば、コンパイル結果をキャッシュする。
  #
  def self.run( filename, ctxt=nil )
    s = _result_file( filename )
    print _exec( "_buf='';#{s}\n_buf.to_s\n", ctxt )
  end


  ##
  # テンプレート文字列を適用し、レンダリングし、表示する。
  #
  #@param  [String]  tstr       テンプレート文字列
  #@param  [Object,Binding] ctxt     実行コンテキスト
  #@note
  # キャッシュはしない。
  #
  def self.run_str( tstr, ctxt=nil )
    tobj = AlTemplate.new( tstr )
    print tobj.result( ctxt )
  end


  ##
  # テンプレートファイル絶対パスを導出（内部メソッド）
  #
  #@param  [String]  filename   ファイル名
  #@return [String]  ファイル名絶対パス
  #
  def self._expand_path( filename )
    raise "No such file in template. '#{filename}' (AlTemplate::_expand_path() needs string.)"  if filename.class != String
    case filename[0]
    when '/', '\\', '.'
      return File.expand_path( filename )
    else
      return File.expand_path( File.join( AL_TEMPLATE_DIR, filename ) )
    end
  end


  ##
  # erbファイルのコンパイル結果を返す。（内部メソッド）
  #
  #@param  [String]  filename   ファイル名
  #@note
  # キャッシュがあれば、それを使う。
  # 結果に、プリ・ポストアンブルは付かない。
  #
  def self._result_file( filename )
    fname_abs = _expand_path( filename )

    if AL_TEMPLATE_CACHE
      cachefile = File.join( AL_TEMPLATE_CACHE, Alone::encode_uri_component( fname_abs ) )
      cached_src = _read_cachefile( cachefile )
      if cached_src
        return cached_src
      end

      tobj = AlTemplate.new( File.read( fname_abs ) )
      tobj._save_cachefile( cachefile, fname_abs )
    else
      tobj = AlTemplate.new( File.read( fname_abs ) )
    end

    return tobj.src_prim
  end


  ##
  # キャッシュファイルの読み込み（内部メソッド）
  #
  #@param  [String]  cachefile  キャッシュファイル名
  #@return [String]             キャッシュしたerbソース。
  #@return [NilClass]           キャッシュが無い、古い等の場合。
  #
  def self._read_cachefile( cachefile )

    # open cachefile
    begin
      file = File.open( cachefile, "r" )
    rescue
      return nil
    end
    cachefile_mtime = File.mtime( cachefile )
    file.flock( File::LOCK_SH )

    catch(:error_exit) do
      # check signature
      throw :error_exit  if file.gets().chomp != CACHE_SIGNATURE

      # check component file's mtime
      while text = file.gets() do
        text.chomp!
        break if text == ""

        begin
          throw :error_exit  if File.mtime( text ) > cachefile_mtime
        rescue
          throw :error_exit
        end
      end

      # read cache source of erb.
      src = file.read()
      file.close()
      return src
    end

    # error_exit
    file.close()
    return nil
  end


  ##
  # テンプレートを実行し、結果を返す。（内部メソッド）
  #
  #@param  [String] src         erbコンパイル結果
  #@param  [Object,Binding] ctxt     実行コンテキスト
  #@return [String]     実行結果
  #
  def self._exec( src, ctxt=nil )
    if ctxt.class == Binding
      return eval( src, ctxt )
    elsif ctxt
      return ctxt.instance_eval( src )
    elsif defined?( $AlController )
      return $AlController.instance_eval( src )
    else
      return eval( src, TOPLEVEL_BINDING )
    end
  end


  ##
  # ファイル名を指定してオブジェクトを生成
  #
  #@param  [String]  filename   ファイル名
  #@return [AlTemplate]         AlTemplateオブジェクト
  #@note
  # キャッシュがあれば、それを使う。
  #
  def self.load_file( filename )
    fname_abs = _expand_path( filename )

    if AL_TEMPLATE_CACHE
      cachefile = File.join( AL_TEMPLATE_CACHE, Alone::encode_uri_component( fname_abs ) )
      cached_src = _read_cachefile( cachefile )
      if cached_src
        tobj = AlTemplate.new()
        tobj.src_prim = cached_src
        return tobj
      end
      tobj = AlTemplate.new( File.read( fname_abs ) )
      tobj._save_cachefile( cachefile, fname_abs )
    else
      tobj = AlTemplate.new( File.read( fname_abs ) )
    end

    return tobj
  end



  #@return [Boolean]            文の改行を取り除くモード
  attr_accessor :trim

  #@return [String]             テンプレートコンパイル結果
  attr_accessor :src_prim

  #@return [Array<Stfing>]      テンプレートを構成するサブファイル名の配列
  attr_reader :component_files


  ##
  # constractor
  #@param [String] input        erbソース文字列
  #
  def initialize( input=nil )
    require 'al_template_main'

    @trim = true
    convert( input )
  end

end


#
# 利便性のため、いくつかのメソッドをグローバルに定義する。
#

##
# html特殊文字のエスケープ
#
def h( s )
  Alone::escape_html( s )
end


##
# URIエンコード
#
def u( s )
  Alone::encode_uri_component( s )
end


##
# リンク用のURIを生成する
#
def make_uri( arg = {} )
  Alone::make_uri( arg )
end
