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
require 'al_main'

##
# AlGraphの各クラスのための名前空間
#
module AlGraph

  ##
  #  描画系クラスのベースクラス
  # 
  class GraphBase

    # make_common_attribute_string()用アトリビュート制御テーブル
    # 値がnilなら無視するアトリビュート、Stringならそれにリネームする。
    ATTR_NAMES = {
      # ignores
      :format => nil,
      :grid => nil,
      :image => nil,
      :length => nil,
      :position => nil,
      :rotate => nil,
      :separate_distance => nil,
      :shape => nil,
      :size => nil,

      # stroke styles
      :stroke_width => "stroke-width",
      :stroke_dasharray => "stroke-dasharray",
      # fonts
      :font_size => "font-size",
      :font_family => "font-family",
      :font_weight => "font-weight",
      :font_style => "font-style",
      :text_anchor => "text-anchor",
      :text_decoration => "text-decoration",
      # opacity
      :stroke_opacity => "stroke-opacity",
    }

    # make_common_attribute_string()用
    # 属性値の後に付けるべき単位
    ATTR_UNITS = {
      "font-size" => "px"
    }


    #@return [Integer] 占める領域の幅
    attr_accessor :width

    #@return [Integer] 占める領域の高さ
    attr_accessor :height

    #@return [GraphOutput] 出力制御オブジェクト
    attr_accessor :output


    ##
    # constructor
    # 
    # @param [Integer] width          幅
    # @param [Integer] height         高さ
    # @param [GraphOutput] output     出力制御オブジェクト
    # 
    def initialize(width, height, output)
      @width = width
      @height = height
      @output = output
      @data_series = []
    end

    protected
    ##
    # データコンテナ追加
    #
    # @param [DataContainer] data_obj  データコンテナオブジェクト
    #
    def add_data_series(data_obj)
      @data_series << data_obj
    end

    ##
    # アトリビュート文字列生成
    # 
    # @param  [Hash] attrs      アトリビュートを格納したハッシュ
    # @return [String]          アトリビュート文字列
    # @note
    #   引数で与えた連想配列 (array) の、特定のキーから xml アトリビュート
    #   文字列を生成して返す。
    #   値がnil、および無視リストに登録があるアトリビュートは対象外とする。
    #
    def make_common_attribute_string(attrs)
      s = ""
      attrs.each { |k,v|
        next if v == nil
        attr_name = ATTR_NAMES.fetch(k.to_sym) rescue k.to_s
        next if !attr_name
        s << %!#{attr_name}="#{v}#{ATTR_UNITS[attr_name]}" !
      }
      s.chop!
      return s
    end

  end

  ##
  #  グラフ本体クラスのベースクラス
  # 
  class GraphUtil < GraphBase

    #@return [Hash] グラフエリアアトリビュート
    attr_accessor :at_graph_area

    #@return [Hash] プロットエリアアトリビュート
    attr_accessor :at_plot_area

    #@return [Hash]  メインタイトルアトリビュート
    attr_accessor :at_main_title

    #@return [Hash]  凡例アトリビュート
    attr_accessor :at_legend

    #@return [Array<String>] 色リスト
    attr_accessor :color_list


    ##
    # constructor
    # 
    # @param [Integer] width          幅
    # @param [Integer] height         高さ
    #
    def initialize(width, height)
      super( width, height, GraphOutput.new )

      @at_graph_area = { :width=>@width, :height=>@height,
        :stroke_width=>1, :stroke=>"black", :fill=>"white" }
      @at_plot_area = { :x=>0, :y=>0, :width=>0, :height=>0 }
      @at_main_title = nil
      @at_legend = nil
      @color_list = [
        '#0084d1', '#004586', '#ff420e', '#ffd320', '#579d1c', '#7e0021',
        '#83caff', '#314004', '#aecf00', '#4b1f6f', '#ff950e', '#c5000b' ]

      # 追加任意タグ
      @aux_tags = []
      # 動作モード (see set_mode() function.)
      @work_mode = {}
    end


    ##
    # 動作モード指定
    #
    # @param  [Symbol] mode   動作モード
    # @note
    # <pre>
    #  設定可能モード
    #   :NO_CONTENT_TYPE   ContentType ヘッダを出力しない
    #   :NO_XML_DECLARATION  XML宣言およびDOCTYPE宣言を出力しない
    #   :NO_SVG_TAG    SVGタグを出力しない
    #   :NO_SVG_TAG_CLOSE  SVG終了タグのみを出力しない
    # </pre>
    #
    def set_mode(mode)
      @work_mode[mode] = true
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
      # calculate insufficiency parameters.
      top ||= @at_plot_area[:y]
      right ||= @width - @at_plot_area[:width] - @at_plot_area[:x]
      bottom ||= 
        @height - @at_plot_area[:height] - @at_plot_area[:y]
      left ||= @at_plot_area[:x]

      # set lot area's parameters
      @at_plot_area[:x] = left
      @at_plot_area[:y] = top
      @at_plot_area[:width] = @width - left - right
      @at_plot_area[:height] = @height - top - bottom
      @at_plot_area[:width] = 0 if @at_plot_area[:width] < 0
      @at_plot_area[:height] = 0 if @at_plot_area[:height] < 0
    end

    ##
    # バッファーへ描画
    # 
    def draw_buffer()
      @output.writer = BufferWriter.new
      self.draw
      return @output.writer.get_output
    end

    ##
    # メインタイトルの追加
    #
    # @param [String] title_string    タイトル文字列
    #
    def add_main_title(title_string)
      set_margin(25, nil, nil, nil)
      @at_main_title = {:title=>title_string, :y=>20, :font_size=>16, :text_anchor=>'middle'}
    end

    ##
    # 凡例表示追加
    #  
    # @note
    #  自動追加されるので、たいていの場合、ユーザがこのメソッドを使うことはないかもしれない。
    #
    def add_legend()
      return if @at_legend

      right = @width - @at_plot_area[:width] - @at_plot_area[:x] + 70
      set_margin(nil, right, nil, nil)
      @at_legend = {:x=>@width - 60, :font_size=>10}
    end

    ##
    # 任意タグを追加
    # 
    # @param [String] text    タグテキスト
    #
    def add_aux_tag(text)
      @aux_tags << text
    end

    ##
    # テキスト追加
    # 
    # @param [Integer] x    X座標
    # @param [Integer] y    Y座標
    # @param [String] text  テキスト
    # @note
    #  addAuxTag()の簡易テキスト版。
    #  フォントサイズの指定などは、<tspan>要素を使える。
    #
    def add_text(x, y, text)
      @aux_tags << "<text x=\"#{x}\" y=\"#{y}\">#{text}</text>\n"
    end

    private
    ##
    # 描画共通部１
    def draw_common1()

      #
      # draw headers. (http header, xml header, and others)
      #
      if ! @work_mode[:NO_CONTENT_TYPE] && defined?(Alone)
        Alone::add_http_header('Content-Type: image/svg+xml')
      end

      unless @work_mode[:NO_XML_DECLARATION]
        @output.printf("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n")
        @output.printf("<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.0//EN\""+
           " \"http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd\">\n")
      end

      unless @work_mode[:NO_SVG_TAG]
        @output.printf("<svg width=\"#{@width}px\" height=\"#{@height}px\""+
      " xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">\n\n" )
      end

      #
      # draw background and border.
      #
      @output.printf("<rect %s />\n", make_common_attribute_string(@at_graph_area))
      if @at_graph_area[:image]
        @output.printf("<image x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" xlink:href=\"%s\" />\n", 0, 0, @width, @height, @at_graph_area[:image])
      end
  
      #
      # draw plot area.
      #
      @output.printf("<rect %s />\n", make_common_attribute_string(@at_plot_area))
      if @at_plot_area[:image]
        @output.printf("<image x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" xlink:href=\"%s\" />\n", @at_plot_area[:x], @at_plot_area[:y],
        @at_plot_area[:width], @at_plot_area[:height], @at_plot_area[:image])
      end

    end

    ##
    # 描画共通部2
    #
    def draw_common2()
      #
      # draw main title.
      #
      if @at_main_title
        @at_main_title[:x] ||= @width / 2
        @output.printf("<text %s>%s</text>\n", make_common_attribute_string(@at_main_title), Alone::escape_html(@at_main_title[:title]))
      end

      #
      # auxiliary tags.
      #
      @aux_tags.each do |atag|
        @output.printf(atag)
      end

      if ! @work_mode[:NO_SVG_TAG] && ! @work_mode[:NO_SVG_TAG_CLOSE]
        @output.printf( "\n</svg>\n" )
      end
    end

  end

  ##
  #  出力制御クラス
  # 
  class GraphOutput
    # 出力に使用するwriterクラス
    attr_accessor :writer

    def initialize()
      # writerクラスのデフォルトはStdoutWriter
      @writer = StdoutWriter.new
    end

    def printf(format, *arg)
      @writer.printf(format, *arg)
    end
  end

  ##
  #  標準出力用writerクラス
  # 
  class StdoutWriter
    def printf(format, *arg)
      Kernel.printf(format, *arg)
    end
  end

  ##
  #  バッファ用writerクラス
  # 
  class BufferWriter
    def initialize()
      # 出力保存用
      @out_buf = ''      
    end

    ##
    # 出力
    # 
    # @param [String] format    出力フォーマット
    # @param arg                出力データ
    # 
    def printf(format, *arg)
      @out_buf << Kernel.sprintf(format, *arg)
    end

    ##
    # 出力結果取得
    # 
    # @return [String]    出力結果
    #
    def get_output()
      return @out_buf
    end
  end

end
