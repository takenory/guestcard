#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# 設定情報保存ファイル
# 必要に応じて書き換えること。

# Aloneライブラリのサーバー上での設置パス
AL_BASEDIR = File.join( File.dirname( __FILE__ ), "lib" )
# テンポラリファイル設置パス
AL_TEMPDIR = "/tmp/"
# 使用キャラクタセット（現在UTF-8固定）
AL_CHARSET = Encoding::UTF_8
# エラーハンドラ
AL_ERROR_HANDLER = "handle_error_display"
#AL_ERROR_HANDLER = "handle_error_static_page"

# ログ（パラメータはLoggger::new メソッドに準ずる）
#AL_LOG_DEV = "/PATH/TO/log.txt"
#AL_LOG_AGE = 0
#AL_LOG_SIZE = 1048576


## for controller

# アプリケーションを導入したディレクトリ絶対パス
AL_CTRL_DIR = File.join( File.dirname( __FILE__ ), "controllers" )


## for form manager

# 最大リクエストサイズ (bytes)
AL_FORM_MAX_CONTENT_LENGTH = 8000000

# htmlタグ生成時の空要素閉じタグ（XHTMLなら "/>"）
AL_FORM_EMPTYTAG_CLOSE = ">"


## for session manager.

# セッションをファイルに保存する場合の場所
AL_SESS_DIR = AL_TEMPDIR

# セッションタイムアウト（秒）
AL_SESS_TIMEOUT = 28800


## for login manager.

# ログインスクリプトのURI
AL_LOGIN_URI = "?ctrl=login"


## for template manager.

# テンプレート保存場所へのパス。ドットはコントローラと同じディレクトリ。
#AL_TEMPLATE_DIR = '.'
AL_TEMPLATE_DIR = File.join( File.dirname( __FILE__ ), "views" )

# テンプレートキャッシュを使う場合のディレクトリ。nilならキャッシュしない。
AL_TEMPLATE_CACHE = nil
#AL_TEMPLATE_CACHE = "/tmp/alcache"

#  テンプレートセクションで使う、出力するhtmlの断片。
#  TODO: エラーハンドラでも使用した。今後もそうかは要検討。
AL_TEMPLATE_HEADER = %Q(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta http-equiv="Content-Script-Type" content="text/javascript">
  <meta http-equiv="Content-Style-Type" content="text/css">
  <link type="text/css" rel="stylesheet" href="/al_style.css">
)
AL_TEMPLATE_BODY = %Q(</head>\n<body>\n)
AL_TEMPLATE_FOOTER = %Q(</body>\n</html>)


$LOAD_PATH << AL_BASEDIR
require 'al_main'
