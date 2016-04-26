#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2012 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#

require "al_worker"
require "timeout"

##
# プログラム実行
#
class AlWorker::Program

  #@return [Hash]  実行中リスト
  @@programs = {}

  #@return [Mutex]  実行中リストmutex
  @@mutex_programs = Mutex.new

  ##
  # プログラム実行中リストのアクセッサ
  #
  def self.programs
    return @@programs
  end


  ##
  # プログラム実行
  #
  #@param [String] program  実行するプログラム名
  #@param [Array]  args     引数
  #@yield                   プログラム終了時の動作
  #@return [AlWorker::Program]
  #@return [NilClass]       実行失敗
  #
  def self.run( program, *args, &block )
    pgm = self.new( program, *args )
    if pgm.run( &block )
      return pgm
    else
      return nil
    end
  end


  ##
  # プログラム名を指定して実行中断
  #
  #@param [String] program  中断するプログラム名
  #@param [Integer,String,Symbol] signal  シグナル
  #
  def self.kill( program, signal = :TERM )
    @@mutex_programs.synchronize {
      @@programs.each_value do |pgm|
        if pgm.program == program
          Process.kill( signal, pgm.pid ) rescue 0
        end
      end
    }
  end


  #@return [Symbol]  状態 ( :none :run :done :error )
  attr_reader :state

  #@return [String]  プログラム名
  attr_accessor :program

  #@return [String]  内部識別名
  attr_accessor :name

  #@return [Array]  引数
  attr_accessor :args

  #@return [Hash]  環境変数
  attr_accessor :env
  
  #@return [Hash]  実行オプション
  attr_accessor :options
  
  #@return [Symbol]  実行終了イベント動作　同期(:sync)／非同期(:async)
  attr_accessor :mode_sync

  #@return [Symbol]  単独実行　単独(:single)／複数（:plural)
  attr_accessor :mode_single
  
  #@return [Proc]  プログラム実行終了時の動作
  attr_accessor :at_end

  #@return [Integer]  プロセスID
  attr_reader :pid

  #@return [Process::Status]  プロセス終了ステータス
  attr_reader :process_status

  #@return [Symbol]  プログラムの終了時　終了させられる(:kill)／留まる(:stay)
  attr_accessor :at_system_exit

  #@return [Mutex]  waitメソッド同期用
  attr_accessor :mutex_wait


  ##
  # constructor
  #
  #@param [String] program  実行するプログラム名
  #@param [Array]  args     引数
  #
  def initialize( program = nil, *args )
    @state = :none
    @program = program.dup
    @args = args
    @env = {}
    @options = {}
    @mode_sync = :sync
    @mode_single = :single
    @at_end = nil
    @at_system_exit = :kill
    @mutex_wait = Mutex.new
  end


  ##
  # 実行する
  #
  #@param [Array] arg   ブロック内に渡す引数
  #@yield               タイムアップ時の動作
  #@return [Boolean]    開始できたか？
  #
  def run( *arg )
    # ２重実行防止
    return false  if @state == :run
    if @mode_single == :single
      @name ||= @program
      @@mutex_programs.synchronize {
        return false  if @@programs[@name]
        @@programs[@name] = self
      }
    end

    # プログラム実行
    @state = :run
    begin
      if ! @env.empty? || ! @options.empty?
        @pid = spawn( @env, @program, *@args, @options )
      else
        @pid = spawn( @program, *@args )
      end

    rescue =>ex
      @state = :error
      @@mutex_programs.synchronize {
        @@programs.delete( @name )
      }
      raise ex
    end

    if @mode_single != :single
      @name = "#{program}##{pid}"
      @@mutex_programs.synchronize {
        @@programs[@name] = self
      }
    end

    @thread = Thread.start( arg ) { |arg|
      # プロセス終了待ち
      @mutex_wait.synchronize {
        (pid,@process_status) = Process.waitpid2( @pid )
        @state = :done
      }
      @@mutex_programs.synchronize {
        @@programs.delete( @name )
      }

      # 終了時、ブロックが与えられて入れば実行
      if block_given?
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

      # 終了時、Procオブジェクトが与えられていれば実行
      if @at_end
        begin
          if mode_sync == :sync
            AlWorker.mutex_sync.synchronize { @at_end.call( self, *arg ) }
          else
            @at_end.call( self, *arg )
          end

        rescue Exception => ex
          raise ex  if ex.class == SystemExit
          AlWorker.log( ex )
        end
      end
    }

    # waitpid2が実行されたことを確実にする。
    while @mutex_wait.try_lock
      @mutex_wait.unlock()
      break if @state != :run
      Thread.pass()
    end

    return true
  end


  ##
  # 実行中か？
  #
  #@return [Boolean]  実行中か？
  #
  def alive?()
    return @state == :run
  end


  ##
  # 実行中断
  #
  #@param [Integer,String,Symbol] signal  シグナル
  #
  def kill( signal = :TERM )
    return nil  if ! @pid
    Process.kill( signal, @pid ) rescue nil
  end


  ##
  # 実行終了を待つ
  #
  #@param [Numeric] timeout  待ち時間タイムアウト
  #@return [NilClass]        nilならタイムアウト
  #
  def wait( timeout = nil )
    return true  if ! @thread

    if timeout
      begin
        Timeout::timeout( timeout ) {
          @mutex_wait.synchronize {
            # waiting waitpid2 in run().
          }
        }
      rescue Timeout::Error
        return nil
      end
    else
      @mutex_wait.synchronize {
        # waiting waitpid2 in run().
      }
    end
    return true
  end

end

#
# システム終了時、実行したプログラムを終了させる。
#
at_exit {
  AlWorker::Program.programs.each do |name,prog|
    next  if prog.at_system_exit == :stay
    prog.kill()
    prog.kill( :KILL )  if prog.wait( 10 ) == nil
  end
}
