#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# フォームマネージャ テーブル作成SQLのひな形作成


class AlForm

  ##
  # テーブル作成SQLのひな形作成
  #
  #@param [String]  tname       テーブル名
  #@return [String]             SQL
  #
  def generate_sql_table( tname = "TABLENAME" )
    a = []
    @widgets.each do |k,w|
      case w
      when AlInteger
        c = "#{k} integer"
      when AlFloat
        c = "#{k} double precision"
      when AlTimestamp
        c = "#{k} timestamp"
      when AlDate
        c = "#{k} date"
      when AlTime
        c = "#{k} time"
      when AlButton, AlSubmit
        next
      else
        c = "#{k} text"
      end

      if w.required
        c << " not null"
      end
      a << c
    end
    return "create table #{tname} (#{a.join( ', ' )});"
  end
end
