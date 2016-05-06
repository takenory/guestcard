#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# alone : application framework for small embedded systems.
#               Copyright (c) 2009 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
#@brief
# サンプル　ファイルアップロード
#@note
# <input type="file">のウィジェットを表示し、画像ファイルの
# アップロードを待ちます
# submitされたら、その画像を表示します。
# HTMLの仕組みの都合上、画像の表示は、別プロセス get_image.rbが行います。
#

#require '../../lib/alone'
# 個別にrequireする場合
require '../../al_config'
require 'al_template'
require 'al_form'
require 'al_session'

Alone::main() {
  @form = AlForm.new(
    AlFile.new( "file1", :label=>"画像ファイル", :required=>true ),
    AlSubmit.new( "submit1", :value=>"決定", 
                  :tag_attr => {:style=>"float: right;"} ),
  )
  @form.tag_attr = { :enctype=>"multipart/form-data" }

  if @form.validate()

    # テンポラリファイルはこのプロセスの終了とともに消されるので、
    # それを防止する。
    @form.widgets[:file1].save_file()

    # セッション変数を使って、画像ダウンローダへ
    # ファイル情報を渡す。
    AlSession[:fname] = @form[:file1][:saved_name]
    AlSession[:content_type] = @form[:file1][:content_type]
  end

  AlTemplate.run( 'index.rhtml' )
}
