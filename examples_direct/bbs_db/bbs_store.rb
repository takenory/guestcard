#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sequel'

module BbsStore
  DATABASE_NAME = 'data/bbs.db'
  @@db = nil

  def self.open
    @@db = Sequel.sqlite(DATABASE_NAME)
    create_table
    @@db
  end

  def self.table_exist?(table)
    begin
      @@db.schema(table)
      return true
    rescue
      return false
    end
  end

  def self.create_table
    return if table_exist?(:messages)
    db.create_table :messages do
      primary_key :id
      String :name
      String :message
      Time :created_at
    end
  end

  def self.db
    @@db
  end
 end
