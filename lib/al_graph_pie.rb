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

##
#  円グラフ
# 
module AlGraph
  class GraphPie < GraphUtil
    # プロットエリアアトリビュート
    attr_accessor :at_plot_area
    # データラベルアトリビュート（未実装）
    attr_accessor :at_data_labels

    ##
    # constructor
    # 
    # @param [Integer] width    幅
    # @param [Integer] height   高さ
    # 
    def initialize(width = 320, height = 240)
      super
      @at_plot_area = {:x => 10, :y => 10, :fill => '#fff'}
      @at_data_labels = nil

      #
      # make default
      #
      @at_plot_area[:width] = @width - 20
      @at_plot_area[:width] = 0 if @at_plot_area[:width] < 0
      @at_plot_area[:height] = @height - 20
      @at_plot_area[:height] = 0 if @at_plot_area[:height] < 0
    end

    ##
    # データの追加
    # 
    # @param [Array<Numeric>] ydata   データの配列
    # @param [Array<String>] labels   ラベルの配列
    #
    def add_data(ydata, labels)
      ydata.each_with_index do |yd, i|
        color = @color_list[i % @color_list.size]
        @data_series << ContainerPie.new(yd, labels[i], color)
      end

      add_legend unless @at_legend

      return @data_series
    end    

    ##
    # 描画
    # 
    # @visibility private
    def draw()
      #
      # calc some params.
      #
      total = 0.0
      @data_series.each do |ds|
        total += ds.data_value
      end

      @data_series.each do |ds|
        ds.percentage = ds.data_value / total
      end

      cx0 = @at_plot_area[:x] + @at_plot_area[:width] / 2
      cy0 = @at_plot_area[:y] + @at_plot_area[:height] / 2
      if @at_plot_area[:r]
        r = @at_plot_area[:r]
      else
        r = (@at_plot_area[:width] < @at_plot_area[:height]) ? @at_plot_area[:width] : @at_plot_area[:height]
        r = r / 2 - 10
        r = 0 if r < 0
      end

      # 
      #  draw start.
      #
      draw_common1()

      # 
      # draw each pieces.
      # 
      @output.printf("\n<!-- draw pie chart -->\n")

      x1 = 0.0
      y1 = -r.to_f
      total2 = 0.0
      @data_series.each_with_index do |ds, i|
        vector = (total2 + ds.data_value / 2.0 ) / total * 2 * Math::PI
        total2 += ds.data_value
        x2 =  r * Math::sin(total2 / total * 2 * Math::PI)
        y2 = -r * Math::cos(total2 / total * 2 * Math::PI)
        l_arc = (ds.percentage > 0.5) ? 1 : 0

        if (x1 - x2).abs < 0.1 && (y1 - y2).abs < 0.1
          if l_arc == 1
            # 1個のデータのみで100%を占める場合はcircle要素で描画。
            # path要素を使うとarctoの始点・終点が同じ座標になるため期待通り
            # の描画ができない。
            @output.printf(%Q|<circle cx="%d" cy="%d" r="%d" %s title="%s"/>\n|,
              cx0, cy0, r, make_common_attribute_string(ds.at_piece),
              ds.data_value)
          else
            # 0%の要素は何も描画しない。
          end
        else
          if(ds.at_piece[:separate_distance])
            d = ds.at_piece[:separate_distance]
            cx = cx0 + d * Math::sin(vector)
            cy = cy0 - d * Math::cos(vector)
          else
            cx = cx0
            cy = cy0
          end
          @output.printf(%Q|<path d="M0,0 L%f,%f A%d,%d 0 %d,1 %f,%f Z" transform="translate(%d,%d)" %s title="%s"/>\n|,
            x1,y1, r,r, l_arc, x2,y2, cx,cy,
            make_common_attribute_string(ds.at_piece), ds.data_value)
        end
        x1 = x2
        y1 = y2
      end

      # 
      # draw legend
      # 
      @output.printf( "\n<!-- draw legends -->\n" )
      if @at_legend
        unless @at_legend[:y]
          @at_legend[:y] = (@height - @data_series.size *
                            (@at_legend[:font_size] + 4)) / 2
          @at_legend[:y] = 0 if @at_legend[:y] < 0
        end

        attr = @at_legend
        attr[:x] += 10
        attr[:y] += attr[:font_size]

        @data_series.each_with_index do |ds, i|
          @output.printf("<text %s>%s</text>\n",
            make_common_attribute_string(attr),
            Alone::escape_html(ds.legend))
          @output.printf(%!<rect x="%d" y="%d" width="%d" height="%d" stroke="black" stroke-width="1" fill="%s" />\n!,
            attr[:x] - attr[:font_size] - 5,
            attr[:y] - attr[:font_size],
            attr[:font_size], attr[:font_size],
            ds.at_piece[:fill])
          attr[:y] += @at_legend[:font_size] + 4
        end
      end

      draw_common2()
    end

    ##
    # 未実装
    # 
    def add_data_labels()
      @at_data_labels = {:font_size => 9}
    end
  end

  ##
  # 円グラフ用データコンテナ
  #
  class ContainerPie
    # データ値
    attr_accessor :data_value
    # 全体率
    attr_accessor :percentage
    # 凡例文字列
    attr_accessor :legend
    #  グラフアトリビュート
    attr_accessor :at_piece

    ##
    # constructor
    # 
    # @param [Numeric] value  データ値
    # @param [String] legend  凡例文字列
    # @param [String] color   色(HTMLカラーコード)
    # @note
    #  データ列を管理するのではなく、一つの値を管理する。
    #  折れ線用(ContainerLine)などとは思想が違うので注意。
    #
    def initialize(value, legend, color)
      @at_piece = {:stroke_width => 1, :stroke => 'black'}

      @data_value = value
      @legend = legend
      @at_piece[:fill] = color
    end

    ##
    # 色の指定
    # 
    # @param [String] color   色(HTMLカラーコード)
    #
    def set_color(color)
      @at_piece[:fill] = color
    end

    ##
    # セパレート
    # 
    # @param [Integer] dim  距離
    #
    def separate(dim = 20)
      @at_piece[:separate_distance] = dim
    end
  end
end

module AlGraphPie
  ##
  # AlGraph::GraphPieのインスタンス生成
  # 
  # AlGraph::GraphPieのインスタンスを生成して返す。
  # AlGraph::GraphPie.newのかわりにAlGraphPie.newと書くことができる。
  #
  def self.new(*params)
    AlGraph::GraphPie.new(*params)
  end

end
