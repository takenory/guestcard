#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# 管理インターフェース
# AlControllerBaseへ、CRUDインターフェースを追加する。
# アトリビュートとして、固定的に使用するものが多くあるので注意する。
#
# 外部から提供
#  @persist     AlPersistオブジェクト
#  @form        AlFormオブジェクト
#  @search_condition            一覧表示のための検索パラメータ
#  @template_ACTION-NAME        テンプレート名。(option)
#
# 内部で使用
#  @datas	表示用AlPersistオブジェクトの配列
#  @columns	カラム識別名(Symbol)の配列

require 'al_form'
require 'al_template'
require 'al_persist'


class AlControllerBase

  ##
  # (MIF) リンク用のURIをキーを含めて生成する
  #
  #@param [AlPersist]   persist AlPersistオブジェクト
  #@param [Hash<String>] arg    URIに含めるパラメータ
  #@return [String]             生成したURI
  #
  def make_uri_key( persist, arg = {} )
    uri = Alone::make_uri( arg )
    persist.pkeys.each do |k|
      uri << "&#{k}=#{Alone::encode_uri_component(persist[k])}"
    end
    return uri
  end


  ##
  # (MIF) 並べ替え用文字列生成
  #
  #@param  [String]     key     並べ替えする項目
  #@return [String]     加工後
  #@note
  # 並べ替えを順序 (order by xxx asc|desc) をトグル動作とする為に、引数で渡したカラム名を加工する。
  #
  def param_order_by( key )
    return @request[:order_by] == key ? "#{key} desc" : key
  end


  ##
  # (MIF) 一覧表示アクション
  #
  #@note
  # ブラウザから渡されるパラメータとして、以下の３つを使用する。
  #  total_rows
  #  offset
  #  order_by
  #
  def action_list()
    # 検索条件の取得および調整
    form_search_condition = AlForm.new( 
        AlInteger.new( "total_rows", :min=>0 ),
        AlInteger.new( "offset", :min=>0 ),
        AlText.new( "order_by", :validator=>/\A[\w ]+\z/ ) )

    @search_condition ||= {}
    if form_search_condition.validate()
      if @search_condition[:total_rows] && form_search_condition[:total_rows]
        @search_condition[:total_rows] = form_search_condition[:total_rows].to_i
      end
      @search_condition[:offset] ||= form_search_condition[:offset].to_i
      if ! form_search_condition[:order_by].empty?
        @search_condition[:order_by] ||= form_search_condition[:order_by]
      end
    end
    @search_condition[:limit] ||= 20
    @search_condition[:order_by] ||= @persist.pkeys()

    # データの取得
    @datas = @persist.search( @search_condition )

    # 表示用カラム配列作成
    @columns = []
    @form.widgets.each do |k,w|
      next if w.class == AlHidden || w.class == AlSubmit || w.class == AlPassword || w.hidden
      @columns << k
    end

    # 次のリクエストURI生成用インスタンス変数@requestを作る
    @request = AlForm.request_get
    if @persist.search_condition[:total_rows]
      @request[:total_rows] = @persist.search_condition[:total_rows]
    end

    # 表示開始
    AlTemplate.run( @template_list || "#{AL_BASEDIR}/templates/list.rhtml" )
  end


  ##
  # (MIF) 新規登録 フォーム表示アクション
  #
  def action_create()
    delete_foreign_widget()
    @form.action = Alone::make_uri( :action=>'create_submit' )

    AlTemplate.run( @template_create || "#{AL_BASEDIR}/templates/form.rhtml" )
  end


  ##
  # (MIF) 新規登録 確定アクション
  #
  def action_create_submit()
    delete_foreign_widget()

    if ! @form.validate()
      # バリデーションエラーならフォームへ戻す
      AlTemplate.run( @template_create || "#{AL_BASEDIR}/templates/form.rhtml" )
      return
    end

    set_persist_values_from_form()
    @result = @persist.create()
    AlTemplate.run( @template_create_submit || "#{AL_BASEDIR}/templates/form_submit.rhtml" )
  end


  ##
  # (MIF) 更新 フォーム表示アクション
  #
  def action_update()
    raise "Primary key is not given."  if ! @form.validate( @persist.pkeys )
    raise "Read error. #{@form.values}"  if ! @persist.read( @form.values )
    set_form_values_from_persist()

    # フォームの調整
    # プライマリキーとなるウィジェットを変更不可にする
    @persist.pkeys.each do |k|
      @form.widgets[k].set_attr( :readonly=>'readonly' )
    end
    @form.action = Alone::make_uri( :action=>'update_submit' )

    # 表示開始
    AlTemplate.run( @template_update || "#{AL_BASEDIR}/templates/form.rhtml" )
  end


  ##
  # (MIF) 更新 確定アクション
  #
  def action_update_submit()
    if ! @form.validate()
      # バリデーションエラーならフォームへ戻す
      AlTemplate.run( @template_update || "#{AL_BASEDIR}/templates/form.rhtml" )
      return
    end

    set_persist_values_from_form()
    @result = @persist.update()
    AlTemplate.run( @template_update_submit || "#{AL_BASEDIR}/templates/form_submit.rhtml" )
  end


  ##
  # (MIF) 削除 確認画面表示アクション
  #
  def action_delete()
    raise "Primary key is not given."  if ! @form.validate( @persist.pkeys )
    raise "Read error. #{@form.values}"  if ! @persist.read( @form.values )
    set_form_values_from_persist()

    AlTemplate.run( @template_delete || "#{AL_BASEDIR}/templates/delete.rhtml" )
  end


  ##
  # (MIF) 削除 確定アクション
  #
  def action_delete_submit()
    raise "Primary key is not given."  if ! @form.validate( @persist.pkeys )

    set_persist_values_from_form()
    @result = @persist.delete()
    AlTemplate.run( @template_delete_submit || "#{AL_BASEDIR}/templates/delete_submit.rhtml" )
  end


  private
  ##
  # (MIF) 表示用にフォームを調整する
  #
  def delete_foreign_widget()
    @form.widgets.each do |k,w|
      if w.foreign
        @form.delete_widget( k )
      end
    end
  end


  ##
  # (MIF) パーシストからフォームへ値をセット
  #
  def set_form_values_from_persist()
    @form.values = @persist.values
  end


  ##
  # (MIF) フォームからパーシストへ値をセット
  #
  def set_persist_values_from_form()
    @persist.values = @form.values
  end

end
