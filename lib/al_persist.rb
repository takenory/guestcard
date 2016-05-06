#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# データ永続化機構
#


##
# データ永続化 ベースクラス
#
class AlPersist

  #@return [AlRdbw] 使用する RDB wrapper オブジェクト
  attr_reader :persist_base

  #@return [Hash] 管理するアトリビュート
  attr_accessor :values

  #@return [Hash] CxUDメソッドの実行結果（DBwrapperからの結果保存）
  attr_reader :result

  #@return [Array<Symbol>] プライマリキーの配列
  attr_reader :pkeys

  #@return [Hash] 検索条件のキャッシュ
  attr_reader :search_condition


  ##
  # constructor
  #
  #@param [AlRdbw] base         使用する RDB wrapper オブジェクト
  #@param [Array<String,Symbol>,String,Symbol]  keys   プライマリキー
  #
  def initialize( base, keys = nil )
    @persist_base = base
    @values = {}
    @result = nil
    pkey( keys )
    @search_condition = {}
  end


  ##
  # primary key setter
  #
  #@param [Symbol,String]       keys    プライマリキー
  #@return [self]       selfオブジェクト
  #
  def pkey( *keys )
    @pkeys = []

    keys.flatten.each do |k|
      case k
      when String
        @pkeys << k.to_sym
      when Symbol
        @pkeys << k
      when NilClass
        # nothing
      else
        raise 'Needs key by String or Symbol'
      end
    end

    return self
  end


  ##
  # attribute getter
  #
  #@param [Symbol] k    キー
  #@return [String]     値
  #
  def []( k )
    return @values[k.to_sym]
  end


  ##
  # attribute setter
  #
  #@param [Symbol] k    キー
  #@param [String] v    値
  #
  def []=( k, v )
    @values[k.to_sym] = v
  end


  ##
  # 検索時、次ページのオフセット値を得る
  #
  #@return [Integer,Nil]        オフセット値。次ページがなければnil。
  #
  def get_next_offset()
    return nil  if ! @search_condition[:has_next_page]
    return @search_condition[:offset].to_i + @search_condition[:limit].to_i
  end


  ##
  # 検索時、前ページのオフセット値を得る
  #
  #@return [Integer,Nil]        オフセット値。前ページがなければnil。
  #
  def get_previous_offset()
    offset = @search_condition[:offset].to_i
    prev = offset - @search_condition[:limit].to_i

    return nil  if offset <= 0
    return prev < 0 ? 0 : prev
  end

end
