#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# マルチパートフォーマットでPOSTされたデータの解析
#

require "al_form/input_file"


class AlForm
  ##
  # (AlForm) POSTリクエストの取り込み / multipart
  #
  def self.fetch_request_multipart()
    req = {}

    #
    # extract boundary
    #
    boundary = nil
    ENV['CONTENT_TYPE'].split( /\s?;\s/ ).each do |a|
      if /\s*([^=]+)(=([^\s]*))?/ =~ a
        if $1 == 'boundary'
          boundary = '--' + $3
        end
      end
    end
    return if ! boundary

    boundary.force_encoding( Encoding::ASCII_8BIT )

    #
    # process post data
    # STRATEGY:
    #  ステートマシンを使って解析する
    #  ステートは、NONE -> HEADER -> CONTENT_START -> CONTENT_NEXT と遷移する
    #
    STDIN.set_encoding( "ASCII-8BIT" )          # TODO: ruby1.9 only
    remain_bytes = ENV['CONTENT_LENGTH'].to_i
    content = {}
    file = nil
    state = :STATE_NONE
    while remain_bytes > 0 && text = STDIN.gets do
      remain_bytes -= text.length

      #
      # check boundary
      #
      if text.start_with?( boundary )
        state = :STATE_HEADER
        next  if ! content[:name]

        key = content[:name].to_sym
        content[:data_body].force_encoding( AL_CHARSET )
        content[:data_body].chomp!

        case req[key]
        when NilClass
          req[key] = file ? content : content[:data_body]

        when String
          req[key] = [ req[key], content[:data_body] ]

        when Array
          req[key] << content[:data_body]
        end

        if file
          file.flush
          if file.size >= 2
            file.truncate( file.size - 2 )        # -2 is CR,LF
          end
          content[:size] = file.size
          file.close
        end

        content = {}
        file = nil
        next
      end

      #
      # process each content
      #
      case state
      when :STATE_HEADER
        case text.chop
        when /^Content-Disposition:(.+)$/i
          $1.split( ';' ).each do |a|
            if / *([^=]+)(="(.*)")?/ =~ a
              if (content[$1.to_sym] = $3) != nil
                content[$1.to_sym].force_encoding( AL_CHARSET )
              end
            end
          end
          
        when /^Content-Type: *([^ ]+)$/i
          content[:content_type] = $1

        when ''                         # data region starts at next line
          state = :STATE_CONTENT_START
        end
        

      when :STATE_CONTENT_START
        if content[:filename]           # this is input type="file" tag
          uplfile = UploadedFile.new( self )
          content[:tmp_name] = uplfile.path
          file = uplfile.file
          file.write( text )
          content[:data_body] = ''
        else
          content[:data_body] = text    # this is other input tag
        end
        state = :STATE_CONTENT_NEXT
        

      when :STATE_CONTENT_NEXT
        if file
          file.write( text )
        else
          content[:data_body] << text
        end
      end

    end  # end of all read

    @@request_post = req
  end


  ##
  # テンポラリファイル生成
  #
  class UploadedFile

    # ファイルパス
    attr_reader :path

    # ファイルオブジェクト
    attr_reader :file


    ##
    # アップロードファイル消去用ファイナライザ
    #
    # (note)
    # テンポラリファイル消去をAlFormオブジェクトのファイナライザにして
    # UploadedFileオブジェクトの参照がなくなってもファイル自体の存在は、
    # AlFormオブジェクトの生存期間と合致させる。
    #
    def self.remove_uploaded_file( fname )
      proc {
        File.unlink( fname ) rescue 0
      }
    end


    ##
    # constructor
    #
    def initialize( obj )
      @file = nil
      100.times do
        # make filename
        @path = File.join( AlFile.dirname, "al_tmp#{$$}_#{rand(99999999)}" )
        begin
          @file = File.open( @path, File::RDWR|File::CREAT|File::EXCL, 0600 )
          break
        rescue =>ex
          # next loop
        end
      end

      if ! @file
        raise "Can't create temporary file. Fix an AL_TEMPDIR parameter in al_config.rb file, or AlFile.dirname setting."
      end

      ObjectSpace.define_finalizer( obj, UploadedFile::remove_uploaded_file( @path.dup ) )
    end
  end

end
