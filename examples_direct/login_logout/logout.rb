#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'
require 'al_login_main'

Alone::main() {
  AlLogin::logout()
  puts "ログアウトしました"
}
