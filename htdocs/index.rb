#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# エントリーポイント
#
# 導入する環境にあわせて、shebang（一行目）とal_configのパスを書換える。
# CGIそのものが動作しているか確認するには、以下の行を有功にして確認できる。
#  puts "Content-Type: text/plain\r\n\r\nIt works!"

require '../al_config'
require 'al_controller'
