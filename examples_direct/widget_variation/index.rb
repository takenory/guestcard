#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# ウィジェットのバリエーション
#

require '../../lib/alone'

Alone::main() {
  @form = AlForm.new(
    # テキスト系
    AlText.new( "text1", :label=>"テキスト" ),
    AlHidden.new( "hidden1", :label=>"ヒドゥンテキスト" ),
    AlPassword.new( "passowrd1", :label=>"パスワード" ),
    AlTextArea.new( "textarea1", :label=>"テキストエリア" ),

    # セレクター系
    AlCheckboxes.new( "check1", :label=>"チェックボックス",
      :options=>{ :c1=>"チェック１", :c2=>"チェック２", :c3=>"チェック３" } ),
    AlRadios.new( "radio1", :label=>"ラジオボタン",
      :options=>{ :r1=>"ラジオ１", :r2=>"ラジオ２", :r3=>"ラジオ３" } ),
    AlOptions.new( "option1", :label=>"プルダウンメニュー",
      :options=>{ :o1=>"オプション１", :o2=>"オプション２", :o3=>"オプション３" } ),

    # 数字
    AlInteger.new( "integer1", :label=>"整数" ),
    AlFloat.new( "float1", :label=>"実数" ),

    # 日時
    AlDate.new( "date1", :label=>"日付" ),
    AlTime.new( "time1", :label=>"時刻" ),
    AlTimestamp.new( "timestamp1", :label=>"日時" ),

    # メールアドレス
    AlMail.new( "mail1", :label=>"メールアドレス" ),

    # 決定ボタン
    AlSubmit.new( "submit1", :value=>"決定" ),
  )

  if ! @form.validate()
    AlTemplate.run( 'index.rhtml' )
  else
    AlTemplate.run( 'action.rhtml' )
  end
}
