#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'
require './bbs_store'


Alone::main() {
  @messages = []

  db = BbsStore.open
  db[:messages].each do |r|
    @messages << 
      {'hizuke' => r[:created_at].to_s.force_encoding('utf-8'),
       'namae' => r[:name].force_encoding('utf-8'),
       'message' => r[:message].force_encoding('utf-8')}
  end

  AlTemplate.run( 'index.rhtml' )
}
