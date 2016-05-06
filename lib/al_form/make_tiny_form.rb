#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# フォームマネージャ 簡易フォーム生成


class AlForm

  ##
  # 簡易フォームの自動生成
  #
  #@param [Hash] arg    htmlタグへ追加するアトリビュートを指定
  #@return [String]     生成したHTML
  #@note
  # tableタグを使って、位置をそろえている。
  #
  def make_tiny_form( arg = {} )
    r = %Q(<form method="#{@method}" action="#{Alone::escape_html(@action)}")
    (@tag_attr.merge arg).each do |k,v|
      r << %Q( #{k}="#{Alone::escape_html(v)}")
    end
    return "#{r}>\n#{make_tiny_form_main()}</form>\n"
  end


  ##
  # 簡易フォームの自動生成　メインメソッド
  #
  #@note
  # TODO: アプリケーションからこのメソッドが独自によばれることがなさそうなら
  #       make_tiny_form()へ吸収合併を考えること。
  #
  def make_tiny_form_main()
    lines = 0
    r = %Q(<table class="al-form-table">\n)
    hidden = ""
    @widgets.each do |k,w|
      if w.hidden
        hidden << w.make_tag()
        next
      end

      lines += 1
      r << %Q(  <tr class="#{AL_LINE_EVEN_ODD[lines & 1]} #{w.name}">\n)
      if @validation_messages[ k ]
        r << %Q(    <td class="al-form-label-error">#{w.label}</td>\n)
      else
        r << %Q(    <td class="al-form-label">#{w.label}</td>\n)
      end
      r << %Q(    <td class="al-form-value">#{w.make_tag()}</td>\n  </tr>\n)
    end
    r << "</table>\n"
    if ! hidden.empty?
      r << "<div>#{hidden}</div>\n"
    end

    return r
  end
end
