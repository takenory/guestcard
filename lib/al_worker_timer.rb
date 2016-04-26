#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require "al_worker"

##
# タイマー
#
class AlWorker::Timer

  #@return [Boolean]  シングルショットタイマーか？
  attr_reader :is_singleshot

  #@return [Numeric,Time]  タイマー間隔 (sec)
  attr_accessor :interval

  #@return [Symbol]  タイムアップ時の動作　同期(:sync)／非同期(:async)
  attr_accessor :mode_sync

  #@return [Boolean]  動作中か？
  attr_reader :is_start


  ##
  # constructor
  #@note
  # ユーザプログラムからは直接使わない。
  #
  def initialize( a1, a2, a3 )
    @is_singleshot = a1
    @interval = a2
    @mode_sync = a3
    @is_start = false
  end


  ##
  # シングルショットタイマーの生成
  #
  #@overload singleshot( interval )
  #  @param [Numeric]  interval タイマー間隔
  #@overload singleshot( timeup )
  #  @param [Time]  timeup タイムアップ時間
  #@return [AlWorker::Timer]
  #
  def self.singleshot( interval = nil )
    return self.new( true, interval, :sync )
  end


  ##
  # 繰り返しタイマーの生成
  #
  #@param [Numeric]  interval タイマー間隔
  #@return [AlWorker::Timer]
  #
  def self.periodic( interval = nil )
    return self.new( false, interval, :sync )
  end


  ##
  # タイマー開始
  #
  #@param [Array] arg   ブロックに渡す引数
  #@yield               タイムアップ時の動作
  #@return [Boolean]  開始できたか？
  #
  def run( *arg )
    return false  if @is_start
    @is_start = true

    #
    # single shot
    #
    if @is_singleshot
      @thread = Thread.start( arg ) { |arg|
        # sleeping...
        if @interval.is_a?( Numeric )
          sleep @interval  if @interval > 0
        elsif @interval.is_a?( Time )
          dt = @interval.to_f - Time.now.to_f
          sleep dt  if dt > 0
        else
          raise self.to_s + ": sleep time must be Numeric or Time."
        end

        # fire!
        begin
          Thread.exit  if Thread.current[:flag_stop] || ! block_given?
          if mode_sync == :sync
            AlWorker.mutex_sync.synchronize { yield( *arg ) }
          else
            yield( *arg )
          end

        rescue Exception => ex
          raise ex  if ex.class == SystemExit
          AlWorker.log( ex )
        end
        @is_start = false
      }
      return true
    end

    #
    # periodic
    #
    @thread = Thread.start( arg ) { |arg|
      timeup = Time.now.to_f
      loop do
        # sleeping...
        timeup += @interval
        dt = timeup - Time.now.to_f
        if dt > 0
          sleep dt
        else
          timeup = Time.now.to_f
          Thread.pass
        end

        # fire!
        begin
          Thread.exit  if Thread.current[:flag_stop] || ! block_given?
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
    return true
  end


  ##
  # タイマー停止
  #
  def stop()
    @thread[:flag_stop] = true  if @thread
    @is_start = false
  end

end
