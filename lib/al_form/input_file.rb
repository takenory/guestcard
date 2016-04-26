#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# フォームマネージャ ファイルアップロードウィジェット
#


##
# ファイルウィジェット
#
class AlFile < AlWidget

  #@return [String]  テンポラリファイルを作成する場所（ディレクトリ）
  @@dirname = AL_TEMPDIR


  ##
  # dirnameのgetter
  #@return [String]  テンポラリファイルを作成する場所（ディレクトリ）
  #
  def self.dirname
    return @@dirname
  end


  ##
  # dirnameのsetter
  #@param [String] dir  テンポラリファイルを作成する場所（ディレクトリ）
  #
  def self.dirname=( dir )
    @@dirname = dir
  end


  ##
  # (AlFile) バリデート
  #
  #@return [Boolean]            成否
  #
  def validate()
    @message = ""
    if @value.class != Hash
      raise "AlFile needs \@value by hash obj. #{@value.class} given, now.  Maybe enctype is not multipart/form-data."
    end

    if @value[:size] == 0
      if @required
        @message = "#{@label}を指定してください。"
        return false
      end
    end

    return true
  end


  ##
  # (AlFile) HTMLタグの生成
  #
  #@param [Hash] arg            htmlタグへ追加するアトリビュートを指定
  #@return [String]             htmlタグ
  #@note
  # hiddenフラグは未対応。type="file"は動作が特殊なので、hiddenにする意味がない。
  #
  def make_tag( arg = {} )
    r = %Q(<input type="file" name="#{@name}" )
    (@tag_attr.merge arg).each do |k,v|
      r << %Q( #{k}="#{Alone::escape_html(v)}")
    end
    return "#{r} #{AL_FORM_EMPTYTAG_CLOSE}"
  end


  ##
  # (AlFile) アップロードされたファイルの恒久的保存
  #
  #@param [Hash] arg    引数ハッシュ
  #@option arg [String] :basename       付与するファイル名のプリフィックス (ex: "pic_")
  #@option arg [String] :extname        付与するファイル名の拡張子　指定しなければ、アップロードファイルに合わせる (ex: ".jpg")
  #@option arg [String] :permission     保存するファイルのパーミッション　(ex: 0666)
  #@note
  # アップロードされたファイルが保存されているテンポラリファイルを、恒久的なファイルにする。
  # 引数で与えた basenameパラメータへ8文字のランダム数をつけたファイル名を生成して付与する。
  #
  def save_file( arg = {} )
    1000.times do
      # make filename -  "dirname" + "base" + random-part + "extname"
      saved_name = File.join( AlFile.dirname,
        arg[:basename].to_s + "00000000#{rand(99999999)}"[-8,8] +
        (arg[:extname] ? arg[:extname] : File.extname( @value[:filename] )) )

      begin
        File.link( @value[:tmp_name], saved_name )
        File.chmod( arg[:permission], saved_name ) if arg[:permission]
        @value[:saved_name] = saved_name
        return                  # normal return.

      rescue =>ex
        # nothing to do. retry it.
      end
    end

    raise "Can't make persist file."
  end

end
