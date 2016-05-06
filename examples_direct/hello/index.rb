#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'
# 個別にrequireする場合。
#require '../../al_config'
#require 'al_template'

Alone::main() {
  @my_message = "Hello world"

  AlTemplate.run( 'index.rhtml' )
}
