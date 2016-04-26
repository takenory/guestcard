#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# alone : application framework for small embedded systems.
#               Copyright (c) 2009 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
#@brief
# サンプル　ファイルアップロード画像表示部

#require '../../lib/alone'
# 個別にrequireする場合
require '../../al_config'
require 'al_session'

Alone::main() {
  fname = AlSession[:fname]
  content_type = AlSession[:content_type]

  exit if ! File.exist?( fname )

  # TODO: 実用に供するときは、content_typeが画像のものであるか
  #       ホワイトリスト方式で確認すべき。
  Alone::add_http_header( "Content-Type: #{content_type}" )
  print File.read( fname )

  File.unlink( fname )
}
