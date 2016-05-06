#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# フォームマネージャ ウィジェット拡張
#


##
# 数値入力ウィジェット
#
class AlNumber < AlWidget

  #@return [Integer]  最大値
  attr_accessor :max

  #@return [Integer]  最小値
  attr_accessor :min


  ##
  # (AlNumber) HTMLタグの生成
  #
  #@param [Hash] arg            htmlタグへ追加するアトリビュートを指定
  #@return [String]             htmlタグ
  #
  def make_tag( arg = {} )
    if @hidden
      return %Q(<input type="hidden" name="#{@name}" id="#{@name}" value="#{Alone::escape_html( @value )}" #{AL_FORM_EMPTYTAG_CLOSE}\n)
    end

    r = %Q(<input type="text" name="#{@name}" id="#{@name}" value="#{Alone::escape_html( @value )}")
    (@tag_attr.merge arg).each do |k,v|
      r << %Q( #{k}="#{Alone::escape_html(v)}")
    end
    return "#{r} #{AL_FORM_EMPTYTAG_CLOSE}"
  end

end



##
# 整数入力ウィジェット
#
class AlInteger < AlNumber

  ##
  # (AlInteger) バリデート
  #
  #@return [Boolean]            成否
  #
  def validate()
    @message = ""

    if @value == "" || @value == nil
      if @required
        @message = "#{@label}を入力してください。"
        return false
      end
      @value = nil
      return true
    end

    if /^[\s]*[+-]?[\d]+[\s]*$/ !~ @value.to_s
      @message = "#{@label}は整数で入力してください。"
      return false
    end

    v = @value.to_i
    if @max && v > @max
      @message = "#{@label}は、#{@max}以下を入力してください。"
      return false
    end
    if @min && v < @min
      @message = "#{@label}は、#{@min}以上を入力してください。"
      return false
    end
    @value = v

    return true
  end

end



##
# 浮動小数点入力ウィジェット
#
class AlFloat < AlNumber

  ##
  # (AlFloat) バリデート
  #
  #@return [Boolean]            成否
  #
  def validate()
    @message = ""

    if @value == "" || @value == nil
      if @required
        @message = "#{@label}を入力してください。"
        return false
      end
      @value = nil
      return true
    end

    if /^[\s]*[+-]?[\d]+(\.[\d]+)?([eE][+-]?[\d]+)?$/ !~ @value.to_s
      @message = "#{@label}を正しく入力してください。"
      return false
    end

    v = @value.to_f
    if @max && v > @max
      @message = "#{@label}は、#{@max}以下を入力してください。"
      return false
    end
    if @min && v < @min
      @message = "#{@label}は、#{@min}以上を入力してください。"
      return false
    end
    @value = v

    return true
  end

end



##
# タイムスタンプウィジェット
#
#@note
# 年月日と時分秒を扱う
# 内部的にはTimeオブジェクトで保存する。
#
class AlTimestamp < AlWidget

  #@return [Integer]  最大値
  attr_accessor :max

  #@return [Integer]  最小値
  attr_accessor :min


  ##
  # (AlTimestamp) バリデート
  #
  #@return [Boolean]            成否
  #
  def validate()
    require 'time'
    @message = ""

    if @value == "" || @value == nil
      if @required
        @message = "#{@label}を入力してください。"
        return false
      end
      @value = nil
      return true
    end

    begin
      @value = Time.parse( @value.to_s )
    rescue
      @message = "#{@label}を正しく入力してください。"
      return false
    end

    if @max && @value > @max
      @message = "#{@label}は、最大#{@max.strftime('%Y-%m-%d %H:%M:%S')}までで入力してください。"
      return false
    end
    if @min && @value < @min
      @message = "#{@label}は、最小#{@min.strftime('%Y-%m-%d %H:%M:%S')}までで入力してください。"
      return false
    end

    return true
  end


  ##
  # (AlTimestamp) HTMLタグの生成
  #
  #@param [Hash] arg            htmlタグへ追加するアトリビュートを指定
  #@return [String]             htmlタグ
  #
  def make_tag( arg = {} )
    if @hidden
      return %Q(<input type="hidden" name="#{@name}" id="#{@name}" value="#{make_value()}" #{AL_FORM_EMPTYTAG_CLOSE}\n)
    end

    r = %Q(<input type="text" name="#{@name}" id="#{@name}" value="#{make_value()}")
    (@tag_attr.merge arg).each do |k,v|
      r << %Q( #{k}="#{Alone::escape_html(v)}")
    end
    return "#{r} #{AL_FORM_EMPTYTAG_CLOSE}"
  end


  ##
  # (AlTimestamp) HTML値の生成
  #
  #@param  [String,Time] arg 表示値。指定なければ内部値を使う。
  #@return [String]     html文字列
  #
  def make_value( *arg )
    v = arg.empty? ? @value: arg[0]
    if v.class == Time
      return Alone::escape_html( v.strftime('%Y-%m-%d %H:%M:%S') )
    else
      return Alone::escape_html( v )
    end
  end

end



##
# 日付ウィジェット
#
#@note
# 年月日を扱う
# 内部的には時刻を0時に固定したTimeオブジェクトで保存する。
#
class AlDate < AlTimestamp

  ##
  # (AlDate) バリデート
  #
  #@return [Boolean]            成否
  #
  def validate()
    require 'time'
    @message = ""

    if @value == "" || @value == nil
      if @required
        @message = "#{@label}を入力してください。"
        return false
      end
      @value = nil
      return true
    end

    begin
      @value = Time.parse( "#{@value} 00:00:00" )
    rescue
      @message = "#{@label}を正しく入力してください。"
      return false
    end

    if @max && @value > @max
      @message = "#{@label}は、最大#{@max.strftime('%Y-%m-%d')}までで入力してください。"
      return false
    end
    if @min && @value < @min
      @message = "#{@label}は、最小#{@min.strftime('%Y-%m-%d')}までで入力してください。"
      return false
    end

    return true
  end

  ##
  # (AlDate) HTML値の生成
  #
  #@param  [String,Time] arg 表示値。指定なければ内部値を使う。
  #@return [String]     html文字列
  #
  def make_value( *arg )
    v = arg.empty? ? @value: arg[0]
    if v.class == Time
      return v.strftime('%Y-%m-%d')
    else
      return Alone::escape_html( v )
    end
  end

end



##
# 時刻ウィジェット
#
#@note
# 時分秒を扱う
# 内部的には日付を2000年に固定したTimeオブジェクトで保存する。
#
class AlTime < AlTimestamp

  ##
  # (AlTime) バリデート
  #
  #@return [Boolean]            成否
  #
  def validate()
    require 'time'
    @message = ""

    if @value == "" || @value == nil
      if @required
        @message = "#{@label}を入力してください。"
        return false
      end
      @value = nil
      return true
    end

    begin
      @value = Time.parse( "2000-01-01 #{@value}" )
    rescue
      @message = "#{@label}を正しく入力してください。"
      return false
    end

    if @max && @value > @max
      @message = "#{@label}は、最大#{@max.strftime('%H:%M:%S')}までで入力してください。"
      return false
    end
    if @min && @value < @min
      @message = "#{@label}は、最小#{@min.strftime('%H:%M:%S')}までで入力してください。"
      return false
    end

    return true
  end


  ##
  # (AlTime) HTML値の生成
  #
  #@param  [String,Time] arg 表示値。指定なければ内部値を使う。
  #@return [String]     html文字列
  #
  def make_value( *arg )
    v = arg.empty? ? @value: arg[0]
    if v.class == Time
      return Alone::escape_html( v.strftime('%H:%M:%S') )
    else
      return Alone::escape_html( v )
    end
  end

end
