#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require "al_worker"

##
# ファイルディスクリプタ
#
class AlWorker::Fd

  #@return [Symbol]  同期(:sync)／非同期(:async)
  attr_accessor :mode_sync

  #@return [File]  対象のファイルオブジェクト
  attr_accessor :file


  ##
  # ファイルオープン
  #
  #@param [String] path  ファイル名
  #@param [String] mode  オープンモード
  #@return [AlWorker::Fd]
  #@note
  # 簡易記述によるファクトリ
  #
  def self.open( path, mode = "r" )
    file = File.open( path, mode )
    self.new( file )
  end



  ##
  # constructor
  #
  #@param [File] file  ファイルオブジェクト
  #
  def initialize( file )
    @file = file
    @mode_sync = :sync
  end


  ##
  # 読み込み準備完了時
  #
  #@param [Array] arg   ブロック内に渡す引数
  #@yield               完了時動作
  #
  def ready_read( *arg )
    th = Thread.start( arg ) { |arg|
      loop do
        begin
          ret = IO.select( [@file] )
        rescue
          @thread_read = nil
          break
        end
        next if ! ret

        begin
          if mode_sync == :sync
            AlWorker.mutex_sync.synchronize { yield( *arg ) }
          else
            yield( *arg )
          end

        rescue Exception => ex
          raise ex  if ex.class == SystemExit
          AlWorker.log( ex )
        end
      end
    }

    #(note)
    # ready_readからready_readを呼び出されても動くように、
    # 若干の工夫がしてある。
    if @thread_read
      th_bak = @thread_read
      @thread_read = th
      th_bak.kill rescue 0
    else
      @thread_read = th
    end
  end


  ##
  # 書き込み準備完了時
  #
  #@param [Array] arg   ブロック内に渡す引数
  #@yield               完了時動作
  #
  def ready_write( *arg )
    th = Thread.start( arg ) { |arg|
      loop do
        begin
          ret = IO.select( [], [@file] )
        rescue
          @thread_write = nil
          break
        end
        next if ! ret

        begin
          if mode_sync == :sync
            AlWorker.mutex_sync.synchronize { yield( *arg ) }
          else
            yield( *arg )
          end

        rescue Exception => ex
          raise ex  if ex.class == SystemExit
          AlWorker.log( ex )
        end
      end
    }

    if @thread_write
      th_bak = @thread_write
      @thread_write = th
      th_bak.kill rescue 0
    else
      @thread_write = th
    end
  end


  ##
  # クローズ
  #
  def close()
    # (note)
    # ready_*() 中から呼び出されるブロックからコールされる可能性がある。
    # その場合、自分のスレッドをkillしないようにしている。
    # 自分のスレッドは、return後のselectで例外によって終了するだろう。
    #
    if @thread_read && @thread_read.alive? && @thread_read != Thread.current
      @thread_read.kill rescue 0
    end
    if @thread_write && @thread_write.alive? && @thread_write != Thread.current
      @thread_write.kill rescue 0
    end

    @file.close  if ! @file.closed?
  end

end
