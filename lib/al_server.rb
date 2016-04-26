#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# 簡易httpサーバ
#
#@note
# これはライブラリではなく、webrickを利用した独立して動作するhttpサーバである。
#  Usage: ruby al_server.rb [document root path]
#

require 'webrick'
require 'rbconfig'

#
# バージョンチェック
#
if RUBY_VERSION < '1.9.1'
  puts "Ruby version error. needs 1.9.1 or later."
  exit
end

#
# rubyインタプリタの定義
#
RUBYPATH = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']) + RbConfig::CONFIG['EXEEXT']

#
# ドキュメントルートディレクトリの決定
#
document_root = ARGV[0] || File.absolute_path( File.join( File.dirname(__FILE__), "..", "controllers" ))
print "DocumentRoot: #{document_root}\n"

#
# WEBrickサーバ用CGIハンドラの定義。*.rbファイルをCGIプログラムとする。
#
module WEBrick::HTTPServlet
  FileHandler.add_handler( 'rb', CGIHandler )
end

#
# サーバインスタンスの生成
#
httpd = WEBrick::HTTPServer.new(
        :DocumentRoot => document_root,
        :Port => 10080,
        :DirectoryIndex => [ "index.html", "index.htm", "index.rb" ],
        :CGIInterpreter => RUBYPATH
)

#
# 終了シグナルを補足したら、shutdownで終了させるためのハンドラを登録する。
#
Signal.trap( 'INT' ) { httpd.shutdown() }
Signal.trap( 'TERM' ) { httpd.shutdown() }

#
# サーバスタート
#
httpd.start()
