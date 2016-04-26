#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'cgi'
require 'cgi/session'
require 'cgi/session/pstore'
require 'erb'
include ERB::Util

Encoding.default_external = 'UTF-8'
$cgi = CGI.new

##
# 初期フォーム表示
#
def action_index()
  print $cgi.header( "text/html; charset=UTF-8" )

  text1 = "テキスト初期値"
  radio1 = "r3"
  check1 = []
  messages = []

  template = ERB.new( File.read( 'v_form.rhtml' ) )
  template.run( binding )
end


##
# 決定ボタンがクリックされたときの処理
#
def action_post()
  radio1_item = { "r1"=>"男性", "r2"=>"女性", "r3"=>"不明" }
  check1_item = { "c1"=>"音楽", "c2"=>"スポーツ", "c3"=>"読書" }

  text1 = $cgi.params["text1"][0]
  radio1 = $cgi.params["radio1"][0]
  check1 = $cgi.params["check1"]
  messages = []

  #
  # バリデーション
  #
  if text1 == ""
    messages << "名前を入力してください。"
  end
  if ! radio1_item[ radio1 ]
    messages << "性別欄の入力値が不正です。"
  end
  if check1.empty?
    messages << "趣味を入力してください。"
  else
    check1.each do |c|
      if ! check1_item[ c ]
        messages << "趣味欄の入力値が不正です。"
      end
    end
  end

  if ! messages.empty?
    print $cgi.header( "text/html; charset=UTF-8" )
    template = ERB.new( File.read( 'v_form.rhtml' ) )
    template.run( binding )
    return
  end

  #
  # セッション変数へ値保存
  #
  session = CGI::Session.new( $cgi, 
                              "database_manager" => CGI::Session::PStore )
  session["text1"] = text1
  session["radio1"] = radio1
  session["check1"] = check1
  session.close

  #
  # 確認画面表示
  #
  radio1_value = radio1_item[radio1]
  check1_value = ""
  check1.each do |c|
     check1_value += check1_item[c] + " "
  end

  print $cgi.header( "text/html; charset=UTF-8" )
  template = ERB.new( File.read( 'v_confirm.rhtml' ) )
  template.run( binding )
end


##
# コミットが選ばれたときの処理
#
def action_commit()
  radio1_item = { "r1"=>"男性", "r2"=>"女性", "r3"=>"不明" }
  check1_item = { "c1"=>"音楽", "c2"=>"スポーツ", "c3"=>"読書" }

  #
  # セッションから値取り出し
  #
  session = CGI::Session.new( $cgi, 
                              "database_manager" => CGI::Session::PStore )
  text1 = session["text1"]
  radio1 = session["radio1"]
  check1 = session["check1"]
  session.close
  session.delete

  #
  # 最終画面表示
  #
  radio1_value = radio1_item[radio1]
  check1_value = ""
  check1.each do |c|
     check1_value += check1_item[c] + " "
  end

  print $cgi.header( "text/html; charset=UTF-8" )
  template = ERB.new( File.read( 'v_commit.rhtml' ) )
  template.run( binding )
end


##
# キャンセルが選ばれたときの処理
#
def action_cancel()

  #
  # セッションから値取り出し
  #
  session = CGI::Session.new( $cgi, 
                              "database_manager" => CGI::Session::PStore )
  text1 = session["text1"]
  radio1 = session["radio1"]
  check1 = session["check1"]
  session.close
  session.delete
  messages = []

  print $cgi.header( "text/html; charset=UTF-8" )
  template = ERB.new( File.read( 'v_form.rhtml' ) )
  template.run( binding )
end


##
# main
#
action = $cgi.params["action"][0]

if ENV['REQUEST_METHOD'] == 'POST'
  action_post()
elsif action == "commit"
  action_commit()
elsif action == "cancel"
  action_cancel()
else
  action_index()
end
