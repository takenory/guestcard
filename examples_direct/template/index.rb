#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'

Alone::main() {
  @contents_template = "content1.rhtml"
  @page_title = "テンプレートテスト"
  @my_message = "朝　竹久夢二"

  AlTemplate.run( 'main_layout.rhtml' )
}
