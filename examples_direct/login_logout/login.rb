#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'
require 'al_login_main'


##
# ログインサンプル
#
#@note
# AlLoginクラスを継承し、confirm()メソッドを作成して、認証作業を行います。
# 認証結果は、booleanで返します。
#
class MyLogin < AlLogin
  USERLIST = { 'user1'=>'pass2',
               'user2'=>'pass1',
  }

  def confirm()
    return USERLIST[ @values[:user_id] ] == @values[:password]
  end
end

Alone::main() {
  login = MyLogin.new()         # 独自テンプレートファイル名を引数にできます。
  if login.login()
    puts "このメッセージは、直接、当スクリプトにアクセスされ、ログインが成功した時にのみ表示されます。"
    puts "実際のアプリケーションでは、トップページやメニューページへのリダイレクトにするとよいでしょう。"
  else
    # 初回アクセス時、及びログインが成功しなかった場合の処理を
    # ここに書くことができますが、既に表示も終わった後なので、
    # 有用性は限られるでしょう。
  end
}
