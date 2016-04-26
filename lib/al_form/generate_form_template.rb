#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# フォームマネージャ 簡易フォームテンプレート生成


class AlForm

  ##
  # 簡易フォームテンプレートの生成
  # AlTemplateの使用を前提としたフォームのテンプレートを生成する。
  #
  #@param  arg          引数ハッシュ
  #@option arg [Boolean] :use_table            テーブルタグを利用した整形
  #@option arg [Boolean] :use_error_class      バリデーションエラーの時、al-form-label-errorを出力するための動的コードを埋め込む
  #
  def generate_form_template( arg = {} )
    flags = { :use_table=>true, :with_error_class=>true }
    flags.merge!( arg )

    r = "<%= header_section %>\n<title></title>\n\n"
    r << "<%= body_section %>\n\n"
    r << "<%= @form.get_messages_by_html() %>\n\n"
    r << %Q(<form method="<%= @form.method %>" action="<%= @form.action %>">\n)

    if flags[:use_table]
      r << %Q(<table class="al-form-table">\n)
      lines = 0
      @widgets.each do |k,w|
        lines += 1
        r << %Q(  <tr class="#{AL_LINE_EVEN_ODD[lines & 1]} #{w.name}\">\n)
        if flags[:with_error_class]
          r << %Q(    <td class="al-form-label<%= @form.validation_messages[:#{w.name}] ? "-error" : "" %>">#{w.label}</td>\n)
        else
          r << %Q(    <td class="al-form-label">#{w.label}</td>\n)
        end
        r << %Q(    <td class="al-form-value"><%= @form.make_tag(:#{w.name}) %></td>\n  </tr>\n\n)
      end
      r << "</table>\n"
      
    else
      lines = 0
      @widgets.each do |k,w|
        lines += 1
        r << %Q(  <div class="#{AL_LINE_EVEN_ODD[lines & 1]} #{w.name}\">\n)
        if flags[:with_error_class]
          r << %Q(    <span class="al-form-label<%= @form.validation_messages[:#{w.name}] ? "-error" : "" %>">#{w.label}</span>\n)
        else
          r << %Q(    <span class="al-form-label">#{w.label}</span>\n)
        end
        r << %Q(    <span class="al-form-value"><%= @form.make_tag(:#{w.name}) %></span>\n  </div>\n\n)
      end
    end

    r << "</form>\n"
    r << "\n<%= footer_section %>"
    return r
  end

end
