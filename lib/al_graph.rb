# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2010-2011
#                 Inas Co Ltd., FAR END Technologies Corporation,
#                 All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# 
#

require 'al_graph_base'

module AlGraph

  ##
  #  座標軸スーパークラス
  # 
  class Axis < GraphBase

    #@return [Hash]  軸アトリビュート
    attr_accessor :at_scale_line

    #@return [Hash]  目盛アトリビュート
    attr_accessor :at_interval_marks

    #@return [Hash]  目盛ラベルアトリビュート
    attr_accessor :at_labels

    #@return [Hash]  目盛ラベル
    attr_accessor :labels


    ##
    # constructor
    #@param [Integer] width          幅
    #@param [Integer] height         高さ
    #@param [GraphOutput] output     出力制御オブジェクト
    #
    def initialize(width, height, output)
      super
      # 軸アトリビュート
      @at_scale_line = {:stroke => 'black', :stroke_width => 1}
      # 目盛アトリビュート
      @at_interval_marks = 
        {:length => 8, :stroke => '#999999', :stroke_width =>1}
      # 目盛ラベルアトリビュート
      @at_labels = {:font_size => 10}
      # 目盛ラベル(配列)
      @labels = []

      @scale_max = nil          # 目盛り最大値
      @scale_min = nil          # 目盛り最小値
      @scale_interval = nil     # 目盛り幅
      @scale_max_user = nil       # ユーザ設定目盛り最大値
      @scale_min_user = nil       # ユーザ設定目盛り最小値
      @scale_interval_user = nil  # ユーザ設定目盛り幅
      @scale_max_min_width= nil   # 最大値-最小値のキャッシュ
      @flag_reverse = false     # 目盛り逆方向（反転）フラグ
    end

    ##
    # 目盛り最大値のユーザ指定
    #
    # @param [Numeric] v    目盛り最大値
    #
    def set_max(v)
      @scale_max_user = v
    end
    alias max= set_max

    ##
    # 目盛り最大値を取得する
    #
    # @return [Numeric]     現在の目盛り最大値
    #
    def max()
      @scale_max
    end

    ##
    # 目盛り最小値のユーザ指定
    #
    # @param [Numeric] v    目盛り最小値
    #
    def set_min(v)
      @scale_min_user = v
    end
    alias min= set_min

    ##
    # 目盛り最小値を取得する
    #
    # @return [Numeric]     現在の目盛り最小値
    #
    def min()
      @scale_min
    end

    ##
    # 目盛り幅のユーザ指定
    #
    # @param [Numeric] v    目盛り幅
    #
    def set_interval(v)
      @scale_interval_user = v
    end
    alias interval= set_interval

    ##
    # 目盛り逆方向（反転）指示
    #
    # @param f    true時、目盛りを反転させる
    #
    def reverse(f = true)
      @flag_reverse = f
    end

    ##
    # グリッド線の付与
    #
    def add_grid()
      @at_interval_marks[:grid] = true
    end

    ##
    # グリッド線の消去
    #
    def clear_grid()
      @at_interval_marks[:grid] = false
    end

    ##
    # 軸線の消去
    #
    def clear_scale_line()
      @at_scale_line.clear
    end

    ##
    # 間隔マークの消去
    #
    def clear_interval_marks()
      @at_interval_marks.clear
    end

    ##
    # 軸ラベルの設定
    def set_labels(labels)
      @labels = labels
    end

    ##
    # 軸ラベルの消去
    #
    def clear_labels()
     @at_labels.clear
    end
  end
  
  ##
  # X軸クラス
  #
  class XAxis < Axis

    ##
    # constructor
    # 
    # @param [Integer] width          幅
    # @param [Integer] height         高さ
    # @param [GraphOutput] output     出力制御オブジェクト
    #
    def initialize(width, height, output)
      super
      @mode_draw_position = :LEFT
      @at_interval_marks[:grid] = false
    end

    ##
    # 軸描画モード変更
    #
    # @param [Symbol] mode    軸描画モード(:LEFT | :CENTER)
    #
    def change_mode(mode)
      mode_sym = mode.to_sym
      case mode_sym
      when :LEFT, :CENTER
        @mode_draw_position = mode_sym
      end
    end

    ##
    # 目盛り最大値のユーザ指定
    #
    # @param [Numeric] v   目盛り最大値 
    #
    def set_max(v)
      @scale_max_user = v - 1
    end

    ##
    # 目盛り最小値のユーザ指定
    #
    # @param [Numeric] v   目盛り最小値 
    #
    def set_min(v)
      @scale_min_user = v - 1
    end

    ##
    # 目盛りスケーリング
    # 
    # @return     成功時、真
    # @note
    #  あらかじめ与えられているデータ系列情報などを元に、
    #  オートスケール処理など、内部データの整合性をとる。
    #
    def do_scaling()
      @scale_min = 0
      @scale_max = nil
      @scale_interval = 1
  
      #
      # maximum quantity amang registered datas.
      #

      @data_series.each do |ds|
        num = ds.y_data.size - 1
        @scale_max = num if @scale_max == nil || @scale_max < num
      end
      @scale_max = 1 if @scale_max != nil && @scale_max < 1

      #
      # refrect user settings
      #
      @scale_max = @scale_max_user if @scale_max_user
      @scale_min = @scale_min_user if @scale_min_user
      @scale_interval = @scale_interval_user if @scale_interval_user

      return false unless @scale_max
      @scale_max_min_width = @scale_max - @scale_min
      @scale_max_min_width = 1 if @scale_max_min_width == 0

      #
      # check scale intarval value, and adjust.
      #
      if @width.to_i > 0 &&
          !@scale_interval_user &&
          ((@scale_max - @scale_min) / @scale_interval) > @width
        @scale_interval = (@scale_max - @scale_min) / (@width / 2)
      end

      return true
    end


    ##
    # 軸上のピクセル位置を計算する。
    #
    # @param [Numeric] v    実数
    # @return [Integer]     ピクセル位置
    # @note
    #  引数が軸上にない場合、返り値も軸上にはないピクセル位置が返る。
    #
    def calc_pixcel_position(v)
      case @mode_draw_position
      when :LEFT
        return (@width * (v - @scale_min) / @scale_max_min_width.to_f).to_i
      when :CENTER
        return ((2 * @width * (v - @scale_min) + @width) / (@scale_max_min_width + 1) / 2.0).to_i
      end
      return 0
    end

    ##
    # 描画　1st pass
    # 
    # @note
    #  スケール描画　パス１。
    #
    # @visibility private
    def draw_z1()
      #
      # draw interval marks
      #
      if ! @at_interval_marks.empty?
        @output.printf("\n<!-- draw X-axis pass 1 -->\n")
        @output.printf("<g %s>\n", make_common_attribute_string(@at_interval_marks))
        y1 = @height
        y2 = @height
        if @at_interval_marks[:length] < 0 
          y1 = @height - @at_interval_marks[:length]
        else
          y2 = @height - @at_interval_marks[:length]
        end
        y2 = 0 if @at_interval_marks[:grid]

        case @mode_draw_position
        when :LEFT
          i = @scale_min
          while i <= @scale_max do
            x = calc_pixcel_position(i)
            @output.printf(%!  <line x1="%d" y1="%d" x2="%d" y2="%d" />\n!, x, y1, x, y2)
            i += @scale_interval
          end
        when :CENTER
          max_loops = (@scale_max - @scale_min) / @scale_interval + 1
          i = 0
          while i <= max_loops do
            x = (@width * i / max_loops.to_f).to_i
            @output.printf(%!  <line x1="%d" y1="%d" x2="%d" y2="%d" />\n!, x, y1, x, y2)
            i += 1
          end
        end
        @output.printf("</g>\n")
      end
    end

    ##
    # 描画　2nd pass
    # 
    # @note
    #  スケール描画　パス２。
    #
    # @visibility private
    def draw_z2()
      @output.printf("\n<!-- draw X-axis pass 2 -->\n")
  
      #
      # draw scale line
      #
      if @at_scale_line && ! @at_scale_line.empty?
        @output.printf( "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" %s/>\n", 0, @height, @width, @height, make_common_attribute_string(@at_scale_line))
      end

      #
      # draw labels
      #
      unless @at_labels.empty?
        # テキストアンカー位置の決定
        @at_labels[:text_anchor] = 'middle' unless @at_labels[:text_anchor]
    
        # 回転させる時は、回転角に応じて自動調整
        if @at_labels[:rotate]
          if 0 < @at_labels[:rotate] && @at_labels[:rotate] < 180 
            @at_labels[:text_anchor] = 'start'
          elsif -180 < @at_labels[:rotate] && @at_labels[:rotate] < 0
            @at_labels[:text_anchor] = 'end'
          end
        end
        
        @output.printf("<g %s>\n", make_common_attribute_string(@at_labels))

        # ラベル出力
        i = 0
        while (v = @scale_min + @scale_interval * i) <= @scale_max
          if ! @labels.empty? && @labels[v] == nil
            i += 1
            next
          end

          x = calc_pixcel_position(v)
          y = @height + @at_labels[:font_size] + 5
          unless @at_labels[:rotate]
            @output.printf('  <text x="%d" y="%d" >', x, y)
          else
            @output.printf('  <text x="%d" y="%d" transform="rotate(%d,%d,%d)" >', x, y, @at_labels[:rotate], x, y - @at_labels[:font_size] / 2)
          end

          unless @labels.empty?
            v = @labels[v] ? Alone::escape_html(@labels[v]): ""
          else
            v += 1
          end
          @output.printf( "#{v}</text>\n" )
          i += 1
        end
        @output.printf( "</g>\n" )
      end
    end

  end


  ##
  # Y軸クラス
  # 
  class YAxis < Axis

    ##
    # constructor
    # 
    # @param [Integer] width        幅
    # @param [Integer] height       高さ
    # @param [GraphOutput] output   出力制御オブジェクト
    #
    def initialize(width, height, output)
      super
      @at_labels[:text_anchor] = 'end'
      @at_interval_marks[:grid] = true
    end

    ##
    # 目盛りスケーリング
    # 
    # @return   成功時、真。
    # @note
    #  あらかじめ与えられているデータ系列情報などを元に、
    #  オートスケール処理など、内部データの整合性をとる。
    def do_scaling()
      max = nil
      min = nil
      interval = nil

      #
      # search max and min value.
      #
      @data_series.each do |ds|
        max = ds.y_data_max if max == nil || max < ds.y_data_max
        min = ds.y_data_min if min == nil || min > ds.y_data_min
      end
      
      # 空のデータ系列が指定されていた場合のmax, min
      max ||= 0
      min ||= 0

      if max == min
        max += max.abs * 0.5
        min -= min.abs * 0.5
      end
  
      # 
      # max point adjustment.
      #
      diff = max - min
      max += diff * 0.1


      #
      # zero point adjustment.
      #
      diff = max - min
      if min > 0 && diff * 2 > min
        min = 0
      elsif (max < 0 && diff * 2 > -max)
        max = 0
      end

      # 
      # refrect user settings.
      #
      max = @scale_max_user if @scale_max_user
      min = @scale_min_user if @scale_min_user
      interval = @scale_interval_user if @scale_interval_user

      #
      # auto scaling.
      # 
      diff = max - min
      if diff > 0
        # calc interval.
        unless @scale_interval_user
          # .to_fを呼ばないとintervalがRationalオブジェクトになる
          interval = (10 ** (Math.log10(diff).floor - 1)).to_f
          tick = diff / interval
          if tick > 50
            interval *= 10
          elsif tick > 20
            interval *= 5
          elsif tick > 10
            interval *= 2
          end
        end

        #max and min point adjustment.
        max = (max / interval).ceil * interval unless @scale_max_user
        min = (min / interval).floor * interval unless @scale_min_user
      end

      return false unless interval

      @scale_max = max
      @scale_min = min
      @scale_interval = interval
      @scale_max_min_width = @scale_max - @scale_min
      @scale_max_min_width = 1 if @scale_max_min_width == 0

      #
      # check scale intarval value, and fource adjust.
      #
      if @width.to_i > 0 && ((max - min) / interval) > @width 
        @scale_interval = (max - min) / (@width / 2)
      end

      return true
    end

    ##
    # 軸上のピクセル位置を計算する。
    # 
    # @param [Numeric] v    実数
    # @return [Integer]     ピクセル位置
    # @note
    #  引数が軸上にない場合、返り値も軸上にはないピクセル位置が返る。
    #
    def calc_pixcel_position(v)
      if @flag_reverse
        return (@height * (v - @scale_min) / @scale_max_min_width.to_f).to_i
      else
        return @height - (@height * (v - @scale_min) / @scale_max_min_width.to_f).to_i
      end
    end

    ##
    # 描画　1st pass
    # 
    # @note
    #  スケール描画　パス１。
    # 
    # @visibility private
    def draw_z1()
      #
      # draw interval marks
      #
      if ! @at_interval_marks.empty?
        @output.printf("\n<!-- draw Y-axis pass 1 -->\n")
      end
      
      x1 = 0
      x2 = 0
      if @at_interval_marks[:length] < 0
        x1 = @at_interval_marks[:length]
      else
        x2 = @at_interval_marks[:length]
      end
      if @at_interval_marks[:grid]
        x2 = @width
      end

      @output.printf("<g %s>\n", make_common_attribute_string(@at_interval_marks))
      i = 0
      while (v = @scale_min + @scale_interval * i) <= @scale_max
        y = calc_pixcel_position(v)
        @output.printf(%!  <line x1="%d" y1="%d" x2="%d" y2="%d" />\n!, x1, y, x2, y)
        i += 1
      end
      @output.printf("</g>\n")
    end

    ##
    # 描画　2nd pass
    #  
    # @note
    #  スケール描画　パス２。
    # 
    # @visibility private
    def draw_z2()
      @output.printf("\n<!-- draw Y-axis pass 2 -->\n")
      #
      # draw scale line
      #
      if @at_scale_line && ! @at_scale_line.empty?
        @output.printf(%!<line x1="%d" y1="%d" x2="%d" y2="%d" %s/>\n!, 0, 0, 0, @height, make_common_attribute_string(@at_scale_line))
      end

      #
      # draw labels
      #
      unless @at_labels.empty?
        @output.printf("<g %s>\n", make_common_attribute_string(@at_labels))

        i = 0
        while (v = @scale_min +  @scale_interval * i) <= @scale_max do
          @output.printf(%!  <text x="%d" y="%d">!, -5, calc_pixcel_position(v) + @at_labels[:font_size] / 2)

          unless @labels.empty?
            v = @labels[i] ? Alone::escape_html(@labels[i]) : ""
          end
          if @at_labels[:format]
            @output.printf("#{@at_labels[:format]}</text>\n", v)
          else
            @output.printf("#{v}</text>\n")
          end
          i += 1
        end
      end
      @output.printf("</g>\n")
    end

  end


  ##
  # 第２Ｙ軸クラス
  # 
  class Y2Axis < YAxis

    ##
    # constructor
    # 
    # @param [Integer] width          幅
    # @param [Integer] height         高さ
    # @param [GraphOutput] output     出力制御オブジェクト
    #
    def initialize(width, height, output)
      super
      @at_labels[:text_anchor] = 'start'
      @at_interval_marks[:grid] = false
    end

    ##
    # 描画　1st pass
    # 
    # @note
    #  スケール描画　パス１。
    # 
    # @visibility private
    def draw_z1()
      #
      # draw interval marks
      #
      if ! @at_interval_marks.empty?
        @output.printf("\n<!-- draw Y2-axis pass 1 -->\n")

        x1 = @width
        x2 = @width
        if @at_interval_marks[:length] < 0 
          x1 = @width - @at_interval_marks[:length]
        else 
          x2 = @width - @at_interval_marks[:length]
        end
        if @at_interval_marks[:grid]
          x2 = 0
        end
        
        @output.printf("<g %s\n>", make_common_attribute_string(@at_interval_marks))
        i = 0
        while ((v = @scale_min + @scale_interval * i) <= @scale_max)
          i += 1
          y = calc_pixcel_position(v)
          @output.printf(%!  <line x1="%d" y1="%d" x2="%d" y2="%d" />\n!, x1, y, x2, y)
        end
        @output.printf("</g>\n")
      end
    end

    ##
    # 描画　2nd pass
    # 
    # @note
    #  スケール描画　パス２。
    #
    # @visibility private
    def draw_z2()
      @output.printf("\n<!-- draw Y2-axis pass 2 -->\n")

      #
      # draw scale line
      #
      if @at_scale_line && ! @at_scale_line.empty?
        @output.printf(%!<line x1="%d" y1="%d" x2="%d" y2="%d" %s/>\n!, @width, 0, @width, @height, make_common_attribute_string(@at_scale_line))
      end

      # 
      # draw labels
      # 
      unless @at_labels.empty?
        @output.printf("<g %s>\n", make_common_attribute_string(@at_labels))
        i = 0
        while ((v = @scale_min + @scale_interval * i) <= @scale_max)
          @output.printf('  <text x="%d" y="%d">', @width + 5, calc_pixcel_position(v) + @at_labels[:font_size] / 2)

          unless @labels.empty?
            v = @labels[i] ? Alone::escape_html(@labels[i]) : ""
          end

          if @at_labels[:format]
            @output.printf("#{@at_labels[:format]}</text>\n", v)
          else
            @output.printf( "#{v}</text>\n")
          end
          i += 1
        end
        @output.printf("</g>\n")
      end
    end
  end

  ##
  #  折れ線と棒グラフ用クラス
  # 
  # @note
  #  ユーザがnewして利用するクラス。
  #
  class Graph < GraphUtil

    # マーカ形状リスト（折れ線グラフのみ）
    SHAPELIST = [:cock, :circle, :rectangle, :diamond, :triangle]

    #@return [Hash]  プロットエリアアトリビュート
    attr_accessor :at_plot_area

    #@return [Hash]  Ｘ軸タイトルアトリビュート
    attr_accessor :at_xaxis_title

    #@return [Hash]  Ｙ軸タイトルアトリビュート
    attr_accessor :at_yaxis_title

    #@return [XAxis]  Ｘ軸オブジェクト
    attr_accessor :x_axis

    #@return [YAxis]  Ｙ軸オブジェクト
    attr_accessor :y_axis

    #@return [Y2Axis]  Ｙ２軸オブジェクト（もしあれば）
    attr_accessor :y2_axis

    #@return [LinePlot]  折れ線グラフオブジェクト
    attr_accessor :line_plot

    #@return [BarPlot]  棒グラフオブジェクト
    attr_accessor :bar_plot

    ##
    # constructor
    # 
    # @param [Integer] width      幅
    # @param [Integer] height     高さ
    #
    def initialize(width = 320, height = 240)
      super

      @at_plot_area = {:x => 40, :y =>10, :fill => '#eee'}
      @at_xaxis_title = nil
      @at_yaxis_title = nil
      @y2_axis = nil
      @line_plot = nil
      @bar_plot = nil
      
      # make default
      @at_plot_area[:width] = @width - 50
      @at_plot_area[:width] = 0 if @at_plot_area[:width] < 0
      @at_plot_area[:height] = @height - 30
      @at_plot_area[:Height] = 0 if @at_plot_area[:height] < 0
      @x_axis =
        XAxis.new(@at_plot_area[:width], @at_plot_area[:height], @output) 
      @y_axis =
        YAxis.new(@at_plot_area[:width], @at_plot_area[:height], @output) 
    end

    ##
    # 折れ線の追加
    #
    # @param [Array<Numeric>] ydata   データの配列
    # @param [String] legend          データの名前（凡例）
    # @return [ContainerLine]         データコンテナオブジェクト
    #
    def add_data_line(ydata, legend = '')
      data_obj = add_data_line_common(ydata, legend)
      data_obj.x_axis = @x_axis
      data_obj.y_axis = @y_axis
      data_obj.plot = @line_plot

      data_obj.at_plot_line[:stroke] = data_obj.at_marker[:fill] = @color_list[ @data_series.size % @color_list.size ]
      data_obj.at_marker[:shape] = SHAPELIST[ @data_series.size % SHAPELIST.size ]

      @x_axis.add_data_series(data_obj)
      @y_axis.add_data_series(data_obj)

      return data_obj
    end

    ##
    # 折れ線の第２Ｙ軸上への追加
    #
    # @param [Array<Numeric>] ydata   データの配列
    # @param [String] legend          データの名前（凡例）
    # @return [ContainerLine]         データコンテナオブジェクト
    #
    def add_data_line_y2(ydata, legend = nil)
      data_obj = add_data_line_common(ydata, legend)

      unless @y2_axis
        @y2_axis =
          Y2Axis.new(@at_plot_area[:width], @at_plot_area[:height],@output)
        right = @width - @at_plot_area[:width] - @at_plot_area[:x] + 20
        set_margin(nil, right, nil, nil)
      end

      data_obj.x_axis = @x_axis
      data_obj.y_axis = @y2_axis
      data_obj.plot = @line_plot

      data_obj.at_plot_line[:stroke] = data_obj.at_marker[:fill] = @color_list[ @data_series.size % @color_list.size ]
      data_obj.at_marker[:shape] = SHAPELIST[ @data_series.size % SHAPELIST.size ]

      @x_axis.add_data_series(data_obj)
      @y2_axis.add_data_series(data_obj)

      return data_obj
    end

    ##
    # 棒グラフの追加
    # 
    # @param [Array<Numeric>] ydata   データの配列
    # @param [String] legend          データの名前（凡例）
    # @param [ContainerBar]           base_bar 積み重ねする場合、ベースになるデータコンテナ
    # @return [ContainerBar]          データコンテナオブジェクト
    # 
    def add_data_bar(ydata, legend = nil, base_bar = nil)
      data_obj = add_data_bar_common(ydata, legend, base_bar)
      data_obj.x_axis = @x_axis
      data_obj.y_axis = @y_axis
      data_obj.plot = @bar_plot
      data_obj.at_bar[:fill] = @color_list[ @data_series.size % @color_list.size ]

      @x_axis.add_data_series(data_obj)
      @y_axis.add_data_series(data_obj)

      return data_obj
    end

    ##
    # 描画
    #
    # @note
    # 管理下のオブジェクトを次々とcallして、全体を描画する。
    # （ユーザが個々の内部オブジェクトのdrawメソッドを使うことは無い）
    #
    def draw()
      #
      # scaling.
      #
      if ! @x_axis.do_scaling || ! @y_axis.do_scaling
        raise "Wrong data. Can't auto scaling."
        return
      end

      if @y2_axis && ! @y2_axis.do_scaling
        raise "Wrong data. Can't auto scaling."
        return
      end

      #
      # draw base items.
      #
      draw_common1

      #
      # output plot area's clipping path.
      #
      @output.printf(%!<clipPath id="plotarea">\n!)
      @output.printf(%!  <rect x="%d" y="%d" width="%d" height="%d" />\n!, -5, -5, @at_plot_area[:width] + 10, @at_plot_area[:height] + 10)
      @output.printf("</clipPath>\n")

      #
      # grouping in plot items.
      #
      @output.printf(%!<g transform="translate(%d,%d)">\n!, @at_plot_area[:x], @at_plot_area[:y])

      #
      # draw X,Y axis
      #
      @x_axis.draw_z1()
      @y_axis.draw_z1()
      @y2_axis.draw_z1() if @y2_axis

      @x_axis.draw_z2()
      @y_axis.draw_z2()
      @y2_axis.draw_z2() if @y2_axis

      #
      # draw data series.
      #
      @output.printf("\n<!-- draw lines and bars in clipping path -->\n")
      @output.printf(%!<g clip-path="url(#plotarea)">\n!)

      @bar_plot.draw() if @bar_plot
      @line_plot.draw() if @line_plot

      @output.printf("</g><!-- end of clip -->\n")

      #
      # end of group
      #
      @output.printf("</g><!-- end of plot area -->\n\n")
  
  
      #
      # draw legend
      #
      if @at_legend
        unless @at_legend[:y] 
          @at_legend[:y] = (@height - @data_series.size * (@at_legend[:font_size] + 4)) / 2
          @at_legend[:y] = 0 if (@at_legend[:y] < 0) 
        end

        attr = @at_legend
        attr[:x] += 10
        attr[:y] += attr[:font_size]

        @data_series.each do |ds|
          @output.printf("<text %s>%s</text>\n", make_common_attribute_string(attr), Alone::escape_html(ds.legend))
          ds.plot.draw_legend_marker(attr[:x] - 10, (attr[:y] - attr[:font_size] / 3.0).to_i, ds)
          attr[:y] += @at_legend[:font_size] + 4
        end
      end

      #
      # draw x-axis title
      #
      if @at_xaxis_title
        unless @at_xaxis_title[:x]
          @at_xaxis_title[:x] = @at_plot_area[:x] + @at_plot_area[:width] / 2
        end
        unless @at_xaxis_title[:y]
          @at_xaxis_title[:y] = @height - 5
        end
        @output.printf("<text %s>%s</text>\n",
          make_common_attribute_string(@at_xaxis_title),
          Alone::escape_html(@at_xaxis_title[:title]))
      end

      #
      # draw y-axis title
      #
      if @at_yaxis_title
        unless @at_yaxis_title[:x]
          @at_yaxis_title[:x] = @at_yaxis_title[:font_size] + 5
        end

        unless @at_yaxis_title[:y]
          @at_yaxis_title[:y] = @at_plot_area[:y] + @at_plot_area[:height] / 2
        end
        @output.printf(%!<text %s transform="rotate(-90,%d,%d)">%s</text>\n!,
                       make_common_attribute_string(@at_yaxis_title),
                       @at_yaxis_title[:x], @at_yaxis_title[:y],
                       Alone::escape_html(@at_yaxis_title[:title]))
      end
      draw_common2()
    end

    ##
    # プロットエリアのマージン設定
    # 
    # @param [Integer] top        上マージン
    # @param [Integer] right      右マージン
    # @param [Integer] bottom     下マージン
    # @param [Integer] left       左マージン
    # @note
    #  上下左右個別に設定できる。
    #  設定値を変えない場合は、そのパラメータをnilにしてcallする。
    #
    def set_margin(top, right, bottom, left)
      super

      # set axis objects parameters
      @x_axis.width = @at_plot_area[:width]
      @x_axis.height = @at_plot_area[:height]
      @y_axis.width = @at_plot_area[:width]
      @y_axis.height = @at_plot_area[:height]
      if @y2_axis
          @y2_axis.width = @at_plot_area[:width]
          @y2_axis.height = @at_plot_area[:height]
      end
    end

    ##
    # Ｘ軸タイトルの追加
    #
    # @param [String] title_string    タイトル文字列
    #
    def add_xaxis_title(title_string)
      set_margin(nil, nil, 35, nil)
      @at_xaxis_title = 
        {:title => title_string, :font_size => 12, :text_anchor => 'middle'}
    end

    ##
    # Ｙ軸タイトルの追加
    #
    # @param [String] title_string    タイトル文字列
    #
    def add_yaxis_title(title_string)
      set_margin(nil, nil, nil, 50)
      @at_yaxis_title = 
        {:title => title_string, :font_size => 12, :text_anchor => 'middle'}
    end

    private

    ##
    # 折れ線の追加　内部処理
    # 
    # @param [Array<Numeric>] ydata   データの配列
    # @param [String] legend          データの名前（凡例）
    # @return [ContainerLine]         データコンテナオブジェクト
    # 
    def add_data_line_common(ydata, legend)
      data_obj = ContainerLine.new(ydata, legend)
      @data_series << data_obj

      @line_plot = LinePlot.new(@output) unless @line_plot
      
      @line_plot.add_data_series(data_obj)
      add_legend if  (! @at_legend && ! data_obj.legend.to_s.empty?)

      return data_obj
    end

    ##
    # 棒グラフの追加　内部処理
    #
    # @param [Array<Numeric>] ydata     データの配列
    # @param [String] legend            データの名前（凡例）
    # @param [ContainerBar] base_bar    積み重ねする場合、ベースになるデータコンテナ
    # @return [ContainerBar]            データコンテナオブジェクト
    # 
    def add_data_bar_common(ydata, legend, base_bar)
      #  
      # 積み重ねの場合、Y値を調整。
      #
      if base_bar
        ydata.each_with_index do |yd, i|
          ydata[i] += base_bar.y_data[i] 
        end
      end

      #
      # コンテナオブジェクトの生成
      #
      data_obj = ContainerBar.new(ydata, legend)

      #
      # コンテナを配列に保存
      #
      if base_bar
        data_obj.stack = base_bar
        @data_series.each_with_index do |ds, i|
          if ds == base_bar
            @data_series.insert(i, data_obj)
            break
          end
        end
      else
        @data_series << data_obj
      end

      #
      # その他必要なオブジェクトを生成
      #
      @bar_plot = BarPlot.new(@output) unless @bar_plot
      @bar_plot.add_data_series(data_obj, base_bar)
      @x_axis.change_mode(:CENTER)
      add_legend if ! @at_legend && data_obj.legend

      return data_obj
    end
  end




  ##
  #  折れ線グラフプロットクラス
  # 
  class LinePlot < GraphBase

    ##
    # constructor
    # 
    # @param [GraphOutput] output     出力制御オブジェクト
    #
    def initialize(output)
      super(nil, nil, output)
      @output = output
    end

    ##
    # 描画
    # 
    # @note
    #  管理下のデータコンテナすべてについて、実際に描画を行う。
    #
    # @visibility private
    def draw()
      @data_series.each do |ds|
        @output.printf("\n<!-- draw line-plot '#{ds.legend}' -->\n")

        #
        # Plot poly line.
        #
        if !ds.at_plot_line.empty?
          @output.printf('<polyline points="')
          i = -1
          ds.y_data.each_with_index do |yd, i|
            next if i < ds.x_axis.min
            break if i > ds.x_axis.max
            next unless yd

            x = ds.x_axis.calc_pixcel_position(i)
            y = ds.y_axis.calc_pixcel_position(yd)
            @output.printf("%d,%d ", x, y)
          end
          @output.printf(%!" %s/>\n!, make_common_attribute_string(ds.at_plot_line))
        end

        #
        # Plot markers
        #
        if !ds.at_marker.empty?
          @output.printf("<g %s>\n", make_common_attribute_string(ds.at_marker))
          ds.y_data.each_with_index do |yd, i|
            next if i < ds.x_axis.min
            break if i > ds.x_axis.max
            next unless yd

            x = ds.x_axis.calc_pixcel_position(i)
            y = ds.y_axis.calc_pixcel_position(yd)
            attr = { :shape => ds.at_marker[:shape],
                     :size => ds.at_marker[:size] }
            attr.merge!( ds.at_marker_several[i] ) if ds.at_marker_several[i]
            draw_marker(x, y, attr)
          end
          @output.printf("</g>\n")
        end

        #
        # Data labels.
        # 
        if ds.at_data_labels
          @output.printf("<g %s>\n", make_common_attribute_string(ds.at_data_labels))
          ds.y_data.each_with_index do |yd, i|
            next if i < ds.x_axis.min
            break if i > ds.x_axis.max
            next unless yd

            x = ds.x_axis.calc_pixcel_position(i)
            y = ds.y_axis.calc_pixcel_position(yd)

            case ds.at_data_labels[:position]
            when 'ABOVE'
              y -= 6
            when 'BELOW'
              y += ds.at_data_labels[:font_size] + 6
            when 'LEFT'
              x -= 6
              y += ds.at_data_labels[:font_size] / 2
            when 'RIGHT'
              x += 6
              y += ds.at_data_labels[:font_size] / 2
            when 'CENTER'
              y += ds.at_data_labels[:font_size] / 2
            end

            @output.printf('  <text x="%d" y="%d" >', x, y)

            if ds.at_data_labels[:format]
              @output.printf("#{ds.at_data_labels[:format]}</text>", yd)
            else
              @output.printf("#{yd}</text>\n")
            end
          end

          @output.printf("</g>\n")
        end

      end
    end

    ##
    # マーカーを描画する
    #
    # @param [Integer] x        Ｘ値
    # @param [Integer] y        Ｙ値
    # @param [Hash] attr        描画アトリビュート
    # @option attr [Symbol] :shape
    #   マーカ種類 (:circle | :rectangle | :diamond | triangle | :cock)
    # @option attr [Integer] :size マーカの大きさ
    # @option attr [String,Integer] :OTHERS その他SVGに出力するアトリビュート
    # 
    # @visibility private
    def draw_marker(x, y, attr)
      attrstr = make_common_attribute_string( attr )

      case attr[:shape] && attr[:shape].to_sym
      when :circle
        r = attr[:size] || 4
        @output.printf(%!  <circle cx="%d" cy="%d" r="%d" %s/>\n!, x, y, r, attrstr)
      
      when :rectangle
        r = attr[:size] || 4
        @output.printf(%!  <rect x="%d" y="%d" width="%d" height="%d" %s/>\n!, x-r, y-r, r*2, r*2, attrstr)

      when :diamond
        r = attr[:size] || 5
        @output.printf(%!  <polygon points="%d,%d %d,%d %d,%d %d,%d" %s/>\n!, x-r, y, x, y-r, x+r, y, x, y+r, attrstr)

      when :triangle
        r = attr[:size] || 5
        @output.printf(%!  <polygon points="%d,%d %d,%d %d,%d" %s/>\n!, x, y-r, x-r, y+r, x+r, y+r, attrstr)

      when :cock
        r = attr[:size] || 4
        @output.printf(%!  <polygon points="%d,%d %d,%d %d,%d %d,%d" %s/>\n!, x-r, y-r, x+r, y+r, x+r, y-r, x-r, y+r, attrstr)

      end
    end 

    ##
    # 凡例部マーカー描画
    #
    # @param [Integer] x    Ｘ値
    # @param [Integer] y    Ｙ値
    # @param [DataContainer] data_obj   データコンテナオブジェクト
    #
    # @visibility private
    def draw_legend_marker(x, y, data_obj)
      if !data_obj.at_plot_line.empty?
        @output.printf(%!<line x1="%d" y1="%d" x2="%d" y2="%d" %s/>\n!, x-9, y, x+9, y, make_common_attribute_string(data_obj.at_plot_line))
      end

      if !data_obj.at_marker.empty?
        attr = { :shape=>data_obj.at_marker[:shape] }
        attr.merge!( data_obj.at_marker )
        draw_marker(x, y, attr)
      end
    end

  end

  ##
  # バーグラフプロットクラス
  # 
  class BarPlot < GraphBase

    ##
    # constructor
    # 
    # @param [GraphOutput] output   出力制御オブジェクト
    # 
    def initialize(output)
      super(nil, nil, output)
      @output = output

      # 棒のオーバーラップ率（％）
      @overlap = 0
      # 棒の間隔率（％：100%で軸とスペースが同じ幅）
      @spacing = 100
    end

    ##
    # データコンテナ追加
    # 
    # @param [ContainerBar] data_obj  データコンテナオブジェクト
    # @param [ContainerBar] base_bar  積み重ねする場合、ベースになるデータコンテナ
    #
    def add_data_series(data_obj, base_bar)
      if base_bar
        @data_series.each_with_index do |ds, i|
          if ds == base_bar
            @data_series.insert(i, data_obj)
            break
          end
        end
      else
        @data_series << data_obj
      end
    end

    ##
    # 棒どうしのオーバーラップ率指定
    # 
    # @param [Integer] v  オーバーラップ率 (%)
    # @note
    #  0から100を指定する。
    #
    def set_overlap(v)
      @overlap = v
    end
    alias overlap= set_overlap

    ##
    # 棒どうしの間隔指定
    # 
    # @param [Integer] v    間隔率 (%)
    # @note
    #  0から100を指定する。
    #
    def set_spacing(v)
      @spacing = v
    end
    alias spacing= set_spacing

    ##
    # 描画
    # 
    # @note
    #  管理下のデータコンテナすべてについて、実際に描画を行う。
    #
    # @visibility private
    def draw()
      num = @data_series.size
      @data_series.each do |ds|
        num -= 1 if ds.base_container
      end
  
      ov = 1 - @overlap / 100.0   # 棒のオーバーラップ率
      sp = @spacing / 100.0       # 棒幅に対する棒間の率
      w_all = @data_series[0].x_axis.calc_pixcel_position(1) - 
        @data_series[0].x_axis.calc_pixcel_position(0) # 全幅 (px)
      w_b = w_all / ( 1 + ov * (num - 1) + sp)  # 棒幅 (px)
      w_s = w_b * sp / 2          # 間隔幅 (px)

      n = 0
      @data_series.each do |ds|
        @output.printf("\n<!-- draw bar-plot '#{ds.legend}' -->\n")
       
        #
        # Draw bar (1 series)
        #
        @output.printf("<g %s>\n", make_common_attribute_string(ds.at_bar))
        ds.y_data.each_with_index do |yd, i|
          next if i < ds.x_axis.min
          break if i > ds.x_axis.max
          next unless yd
    
          x = ds.x_axis.calc_pixcel_position(i) - (w_all / 2.0)
          x1 = x + w_s + n * w_b * ov
          x2 = x1 + w_b
          unless ds.base_container
            y1 = ds.y_axis.calc_pixcel_position(0)
          else
            y = ds.base_container.y_data[i]
            y1 = ds.y_axis.calc_pixcel_position(y)
          end
          y2 = ds.y_axis.calc_pixcel_position(yd)
          if y1 != y2
            @output.printf(%!  <polyline points="%.2f,%.2f %.2f,%.2f %.2f,%.2f %.2f,%.2f" !, x1, y1, x1, y2, x2, y2, x2, y1)
            if ds.at_bar_several[i]
              @output.printf( make_common_attribute_string( ds.at_bar_several[i] ) + " />\n")
            else
              @output.printf("/>\n")
            end
          end
        end
        @output.printf("</g>\n")

        #
        # Data labels.
        #
        if ds.at_data_labels
          @output.printf("<g %s>\n", make_common_attribute_string(ds.at_data_labels))
          ds.y_data.each_with_index do |yd, i|
            next if i < ds.x_axis.min
            break if i > ds.x_axis.max
            next unless yd
            
            x = ds.x_axis.calc_pixcel_position(i) - (w_all / 2) + w_s +
              n * w_b * ov
            y = ds.y_axis.calc_pixcel_position(yd)

            case ds.at_data_labels[:position]
            when 'ABOVE'
              x += w_b / 2
              y -= 6
            when 'BELOW'
              x += w_b / 2
              y += dx.at_data_labels[:font_size] + 6
            when 'LEFT'
              x -= 3
              y += ds.at_data_labels[:font_size] / 2
            when 'RIGHT'
              x += w_b + 3
              y += ds.at_data_labels[:font_size] / 2
            when 'CENTER'
              x += w_b / 2
              y += ds.at_data_labels[:font_size] / 2
            end
        
            @output.printf('  <text x="%d" y="%d" >', x, y)

            if ds.at_data_labels[:format]
              @output.printf("#{ds.at_data_labels[:format]}</text>", yd)
            else
              @output.printf("#{yd}</text>\n")
            end
          end

          @output.printf("</g>\n")
        end

        n += 1 unless ds.base_container
      end
    end

    ##
    # 凡例部マーカー描画
    # 
    # @param [Integer] x      Ｘ値
    # @param [Integer] y      Ｙ値
    # @param [ContainerBar] data_obj    データコンテナオブジェクト
    #
    # @visibility private
    def draw_legend_marker(x, y, data_obj)
      @output.printf(%!  <rect x="%d" y="%d" width="8" height="8" %s/>\n!, x - 3, y - 3, make_common_attribute_string(data_obj.at_bar))
    end
  end

  ##
  #  データコンテナ　スーパークラス
  # 
  class DataContainer
    #@return [Array<Numeric>] Y値データ
    attr_accessor :y_data

    #@return [Numeric] Y値最大値
    attr_accessor :y_data_max

    #@return [Numeric] Y値最小値
    attr_accessor :y_data_min

    #@return [Hash] データラベルアトリビュート
    attr_accessor :at_data_labels

    #@return [String] 凡例文字列
    attr_accessor :legend
    
    #@return [XAxis] 使用するＸ軸オブジェクト
    attr_accessor :x_axis

    #@return [YAxis] 使用するＹ軸オブジェクト
    attr_accessor :y_axis

    #@return [LinePlot,BarPlot] 使用するプロットオブジェクト
    attr_accessor :plot


    ##
    # constructor
    #
    # @param [Array<Numeric>] ydata   Y値データ
    # @param [String] legend          凡例文字列
    #
    def initialize(ydata, legend = nil)
      @at_data_labels = nil

      @y_data = ydata
      @y_data_max = nil
      @y_data_min = nil
      
      @y_data.each do |y|
        next unless y
        @y_data_max = y if (!@y_data_max || @y_data_max < y)
        @y_data_min = y if (!@y_data_min || @y_data_min > y)
      end
      @legend = legend
    end

    ##
    # 値ラベルを表示
    #
    # @param [String] pos   値ラベルの位置 (ABOVE | BELOW | LEFT | RIGHT | CENTER)
    # @note
    #  位置以外は、デフォルト値で表示するよう設定。
    #
    def add_data_labels(pos = 'ABOVE')
      case pos
      when 'ABOVE', 'BELOW', 'CENTER'
        @at_data_labels =
          {:position => pos, :font_size => 9, :text_anchor => 'middle'}
      when 'LEFT'
        @at_data_labels =
          {:position => pos, :font_size => 9, :text_anchor => 'end'}
      when 'RIGHT'
        @at_data_labels =
          {:position => pos, :font_size => 9, :text_anchor => 'start'}
      end
    end
  end

  ##
  # 折れ線グラフ用データコンテナ
  # 
  # @note
  #  線を消してマーカのみの表示にすることもできる。
  #
  class ContainerLine < DataContainer

    #@return [Hash] 線の描画アトリビュート
    attr_accessor :at_plot_line

    #@return [Hash] マーカーの描画アトリビュート
    attr_accessor :at_marker

    #@return [Hash<Hash>] 個別のマーカーの描画アトリビュート
    attr_accessor :at_marker_several

    ##
    # constructor
    #
    # @param [Array<Numeric>] ydata   Y値データ
    # @param [String] legend          凡例文字列
    #
    def initialize(ydata, legend = nil)
      super

      @at_plot_line = {:stroke_width=>2, :fill=>:none}
      @at_marker = {:format=>nil, :stroke=>:black, :stroke_width=>2}
      @at_marker_several = {}
    end

    ##
    # 線を表示しない
    #
    def clear_line()
      @at_plot_line.clear
    end

    ##
    # マーカーを表示しない
    #
    def clear_marker()
      @at_marker.clear
    end

    ##
    # 色の指定
    # 
    # @param [String] color   色(HTMLカラーコード)
    # @note
    #  折れ線の場合、線とマーカーの両方の色変えなければならないので、
    #  アトリビュートを2ヶ所変更するよりも簡単にするために作成。
    #
    def set_color(color)
      @at_plot_line[:stroke] = color if !@at_plot_line.empty?
      @at_marker[:fill] = color if !@at_marker.empty?
    end
    alias color= set_color

  end


  ##
  #  バーグラフ用データコンテナ
  # 
  class ContainerBar < DataContainer

    #@return [Hash] バーの描画アトリビュート
    attr_accessor :at_bar

    #@return [Hash<Hash>] 個別のバー描画アトリビュート
    attr_accessor :at_bar_several

    #@return [Containerbar] 積み重ねグラフの時、下になるコンテナオブジェクト
    attr_reader :base_container


    ##
    # constructor
    #
    # @param [Array<Numeric>] ydata   Y値データ
    # @param [String] legend          凡例文字列
    #
    def initialize(ydata, legend = nil)
      super

      @at_bar = {:stroke_width=>1, :stroke=>:black}
      @at_bar_several = {}
      @base_container = nil
    end

    ##
    # 積み重ね設定
    # 
    # @param [ContainerBar] base    ベースになるデータコンテナ
    #
    def set_stack(base)
      @base_container = base
    end
    alias stack= set_stack

    ##
    # 色の指定
    # 
    # @param [String] color   色(HTMLカラーコード)
    # @note
    #  ContainerLine::color= との対称性のため定義。
    #
    def set_color(color)
      @at_bar[:fill] = color
    end
    alias color= set_color
  end


  ##
  # AlGraph::Graphのインスタンス生成
  # 
  # AlGraph::Graphのインスタンスを生成して返す。
  # AlGraph::Graph.newのかわりにAlGraph.newと書くことができる。
  #
  def self.new(*params)
    AlGraph::Graph.new(*params)
  end

end
