#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'
require './database'

Alone::main() {
  @addresses = Address.all
  AlTemplate.run( 'index.html.erb' )
}
