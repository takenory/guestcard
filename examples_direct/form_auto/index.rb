#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# フォーム利用サンプル
# フォームHTML自動生成版

require '../../lib/alone'
# 個別にrequireする場合
#require '../../al_config'
#require 'al_template'
#require 'al_form'

Alone::main() {
  @form = AlForm.new(
    AlText.new( "text1", :label=>"名前", :value=>"Boz Scaggs." ),
    AlRadios.new( "radio1", :label=>"性別", :value=>"r3",
                  :options=>{ :r1=>"男性", :r2=>"女性", :r3=>"不明" } ),
    AlCheckboxes.new( "check1", :label=>"趣味", :required=>true,
                  :options=>{ :c1=>"音楽", :c2=>"スポーツ", :c3=>"読書" } ),
    AlSubmit.new( "submit1", :value=>"決定",
                  :tag_attr=> {:style=>"float: right;"} )
  )

  if ! @form.validate()
    AlTemplate.run( 'form.rhtml' )
  else
    AlTemplate.run( 'action.rhtml' )
  end
}
