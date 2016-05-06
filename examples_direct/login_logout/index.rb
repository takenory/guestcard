#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#


# サンプルの都合により、ここで AL_LOGIN_URIを定義していますが、
# 本来は、al_config.rb 内で定義すべきです。
#
AL_LOGIN_URI = "/login_logout/login.rb"  if ! Object.const_defined?( :AL_LOGIN_URI )


require '../../lib/alone'
require 'al_login'

Alone::main() {
  # ここは、ログインしていないと実行されません。
  AlTemplate.run( 'index.rhtml' )
}
