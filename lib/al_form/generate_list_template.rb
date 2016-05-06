#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# フォームマネージャ 簡易リスト表示テンプレートの生成


class AlForm

  ##
  # 簡易リスト表示テンプレートの生成
  # AlTemplateの使用を前提とした一覧リスト表示形式のテンプレートを生成する。
  #
  #@param  arg          引数ハッシュ
  #@option arg [Boolean] :use_table            テーブルタグを利用した整形
  #
  def generate_list_template( arg = {} )
    flags = { :use_table=>true }
    flags.merge!( arg )

    r = %Q(<%= header_section %>\n<title></title>\n\n)
    r << %Q(<%= body_section %>\n\n)

    r << %Q(<table class="al-list-table">\n)
    r << %Q(  <tr>\n)
    @widgets.each do |k,w|
      next if w.class == AlHidden || w.class == AlPassword || w.hidden || w.is_a?( AlButton )
      r << %Q(    <th>#{w.label}</th>\n)
    end
    r << %Q(    <th>&nbsp;</th>\n)
    r << %Q(  </tr>\n)

    r << %Q(  <% @datas.each do |d| %>\n)
    r << %Q(  <tr>\n)
    @widgets.each do |k,w|
      next if w.class == AlHidden || w.class == AlPassword || w.hidden || w.is_a?( AlButton )
      r << %Q(    <td><%= @form.widgets[:#{w.name}].make_value( d[:#{w.name}] ) %></td>\n)
    end

    r << %Q(    <td class="al-navigation">\n)
    r << %Q(      <a href="<%=h make_uri_key(d, :action=>"update") %>">変更</a>\n)
    r << %Q(      <a href="<%=h make_uri_key(d, :action=>"delete") %>">削除</a>\n)
    r << %Q(    </td>\n)

    r << %Q(  </tr>\n)
    r << %Q(  <% end %>\n)
    r << %Q(</table>\n)
    r << %Q(<hr>\n)


    r << %Q(  <div class="al-navigation">
    <% if @persist.get_previous_offset() %>
    <a href="<%=h make_uri( @request.merge({:offset=>@persist.get_previous_offset()}) ) %>">≪前ページ</a>
    <% else %>
    <span class="al-inactive">≪前ページ</span>
    <% end %>

    <% if @persist.get_next_offset() %>
    <a href="<%=h make_uri( @request.merge({:offset=>@persist.get_next_offset()}) ) %>">次ページ≫</a>
    <% else %>
    <span class="al-inactive">次ページ≫</span>
    <% end %>

    <a href="<%=h make_uri( :action=>"create" ) %>">新規登録</a>
  </div>
)

    r << %Q(\n<%= footer_section %>)
    return r
  end

end
