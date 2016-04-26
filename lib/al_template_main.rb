#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# テンプレートマネージャ メイン処理
# erbソース中のコマンドを実行しながら、コンパイルする。
# 実装の簡易性を保つため、現在は疑似コマンドのネストはできない。
#
#@note
# このファイルに含まれるいくつかのメソッドは、Erubis version 2.6.2 から
# 著作者の許可を得て転用させていただきました。
#  (http://www.kuwata-lab.com/erubis)
#
# This file includes some method from the Erubis version 2.6.2 origin.
# Special thanks to Mr. Makoto Kuwata.
#

##
# テンプレートマネージャ
#
class AlTemplate

  EMBEDDED_PATTERN = /<%(=|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m
  COMMAND_EXTRACTOR = /\A *(include|expand|header_section|body_section|footer_section|h|u)(([ (].*)|\z)/


  ##
  # erbソースをコンパイルして保持。
  #
  #@param [String] input        erbソース文字列
  #@note
  # 実質の、初期化メソッド。
  #
  def convert( input )
    @src_prim = ""
    @component_files = []

    convert_input( @src_prim, input ) if input
  end


  ##
  # erbコンパイル結果を返す。
  #
  #@return [String]     コンパイル結果
  #
  def src()
    return "_buf='';#{@src_prim}\n_buf.to_s\n"
  end


  ##
  # テンプレートを実行し、結果を返す。
  #
  #@param  [Object,Binding] ctxt     実行コンテキスト
  #@return [String]     実行結果
  #
  def result( ctxt=nil )
    begin
      return AlTemplate::_exec( src, ctxt )

    rescue => ex
      raise ex, "Error in template. #{ex.message}"
    end
  end


  ##
  # コンパイル結果をキャッシュへ保存（内部メソッド）
  #@param [String] cachefile キャッシュファイル名
  #@param [String] fname_abs テンプレートファイル絶対パス
  #
  def _save_cachefile( cachefile, fname_abs )
    file = File.open( cachefile, "w" )
    file.flock( File::LOCK_EX )
    file.puts( CACHE_SIGNATURE )
    file.puts( fname_abs )
    @component_files.each do |a|
      file.puts( a )
    end
    file.puts( "" )
    file.puts( @src_prim )
    file.close()
  end


  private

  ##
  # erbコンパイル メイン
  #
  #@param [String] src          結果の追加先
  #@param [String] input        erbソース
  #@note
  # (base) erubis/converter.rb  module Basic::Converter
  #
  def convert_input(src, input)
    pos = 0
    is_bol = true     # is beginning of line

    input.scan(EMBEDDED_PATTERN) do |indicator, code, tailch, rspace|
      match = Regexp.last_match()
      len  = match.begin(0) - pos
      text = input[pos, len]
      pos  = match.end(0)
      lspace = (indicator == "=") ? nil : detect_spaces_at_bol(text, is_bol)
      is_bol = rspace ? true : false

      add_text(src, text) if text && !text.empty?

      ## * when '<%= %>', do nothing
      ## * when '<% %>' or '<%# %>', delete spaces if only spaces are around '<% %>'
      case indicator
      when "="                  # <%= %>
        rspace = nil if tailch && !tailch.empty?
        add_text(src, lspace) if lspace
        if COMMAND_EXTRACTOR =~ code
          __send__( "cmd_#{$1}", src, $2 )
        else
          add_expr_literal(src, code)
        end
        add_text(src, rspace) if rspace

      when"#"                   # <%# %>
        n = code.count("\n") + (rspace ? 1 : 0)
        if @trim && lspace && rspace
          add_stmt(src, "\n" * n)
        else
          add_text(src, lspace) if lspace
          add_stmt(src, "\n" * n)
          add_text(src, rspace) if rspace
        end

      when "%"                  # <%% %>
        add_text( src, "#{lspace}<%#{code}#{tailch}%>#{rspace}" )

      else                      # <% %>
        if COMMAND_EXTRACTOR =~ code
          __send__( "cmd_#{$1}", src, $2 )
        elsif @trim && lspace && rspace
          add_stmt(src, "#{lspace}#{code}#{rspace}")
        else
          add_text(src, lspace) if lspace
          add_stmt(src, code)
          add_text(src, rspace) if rspace
        end
      end
    end

    #rest = $' || input                        # ruby1.8
    rest = pos == 0 ? input : input[pos..-1]   # ruby1.9
    add_text(src, rest)
  end

  # (quote) erubis/converter.rb module Converter
  ##
  ## detect spaces at beginning of line
  ##
  def detect_spaces_at_bol(text, is_bol)
    lspace = nil
    if text.empty?
      lspace = "" if is_bol
    elsif text[-1] == ?\n
      lspace = ""
    else
      rindex = text.rindex(?\n)
      if rindex
        s = text[rindex+1..-1]
        if s =~ /\A[ \t]*\z/
          lspace = s
          #text = text[0..rindex]
          text[rindex+1..-1] = ''
        end
      else
        if is_bol && text =~ /\A[ \t]*\z/
          #lspace = text
          #text = nil
          lspace = text.dup
          text[0..-1] = ''
        end
      end
    end
    return lspace
  end


  # (quote) erubis/engine/eruby.rb module RubyGenerator
  def add_text(src, text)
    # convert by gsub  "'" => "\\'",  '\\' => '\\\\'
    src << " _buf << '" << text.gsub(/['\\]/, '\\\\\&') << "';" unless text.empty?
  end

  def add_stmt(src, code)
    #src << code << ';'
    src << code
    src << ';' unless code[-1] == ?\n
  end

  def add_expr_literal(src, code)
    src << ' _buf << (' << code << ').to_s;'
  end


  ##
  # プリプロセスコマンド　サブテンプレートの挿入
  #
  #@param [String]  src         結果の追加先
  #@param [String]  param       パラメータ文字列
  #
  def cmd_include( src, param )
    # check specified fixed string.
    if /\A[\(\s]*["']([^"']+)["'][\)\s]*\z/ =~ param
      fname_abs = AlTemplate::_expand_path( $1 )
      @component_files << fname_abs
      convert_input( src, File.read( fname_abs ) )
    else
      add_stmt( src, "eval(AlTemplate::_result_file(#{param}))" )
    end
  end


  ##
  # プリプロセスコマンド　事前実行展開
  #
  #@param [String]  src         結果の追加先
  #@param [String]  param       パラメータ文字列
  #
  #TODO: 自由なbindingが指定できない。
  #
  def cmd_expand( src, param )
    s = defined?( $AlController ) ? $AlController.instance_eval( param ) : eval( param, TOPLEVEL_BINDING )
    add_text( src, s )
  end


  ##
  # プリプロセスコマンド　ヘッダセクション展開
  #
  def cmd_header_section( src, param )
    add_text( src, AL_TEMPLATE_HEADER )
  end


  ##
  # プリプロセスコマンド　ボディーセクション展開
  #
  def cmd_body_section( src, param )
    add_text( src, AL_TEMPLATE_BODY )
  end


  ##
  # プリプロセスコマンド　フッタセクション展開
  #
  def cmd_footer_section( src, param )
    add_text( src, AL_TEMPLATE_FOOTER )
  end


  ##
  # プリプロセスコマンド　html特殊文字のエスケープ
  #
  def cmd_h( src, param )
    add_expr_literal( src, "Alone::escape_html(#{param})" )
  end


  ##
  # プリプロセスコマンド　URIエンコード
  #
  def cmd_u( src, param )
    add_expr_literal( src, "Alone::encode_uri_component(#{param})" )
  end

end
