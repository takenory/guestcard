# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
#@brief
# これは、コントローラを使用するサンプルの為の、簡易ランチャーです。
#  ・ディレクトリリストを表示し、クリックして実行できるようにします。
#  ・ディレクトリ内にREADMEファイルが存在すれば、その一行目をメニューとして表示します。
#

require 'al_template'

TEMPLATE_STR = %Q(
<%= header_section %>
  <title>コントローラ使用サンプル一覧</title>

<%= body_section %>
  <div class="al-page-header">コントローラ使用サンプル一覧</div>
  <p>この画面は、コントローラ指定が無い場合(*1) に動作するデフォルトのコントローラ(*2) が出力しています。
    <div style="margin-left: 4em; font-size: 80%;">
      *1 URIに ctrl=xxx が指定されない場合<br>
      *2 AL_CTRL_DIR に指定したパスのmain.rb<br>
    </div>
  </p>

  <ol>
    <% @app_list.each do |m| %>
    <li><%= m %></li>
    <% end %>
  </ol>

<%= footer_section %>
)

class AlController
  def action_index
    @app_list = []

    Dir.glob( "*" ).sort.each do |dirname|
      next if ! FileTest.directory?( dirname )

      # open README file
      memo_text = nil
      begin
        File.open( File.join( dirname, "README" ) ) do |file|
          memo_text = file.gets().chomp
        end
      rescue
        # nothing to do.
      end
      next if memo_text == ".HIDDEN"

      # make link strings.
      uri = Alone::make_uri( :ctrl => dirname )
      @app_list << "<a href=\"#{uri}\">#{memo_text||dirname}</a>"
    end

    AlTemplate.run_str( TEMPLATE_STR )
  end
end
