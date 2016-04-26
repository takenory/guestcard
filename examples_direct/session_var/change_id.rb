#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'

Alone::main() {
  AlSession::change_session_id()
  Alone::redirect_to( 'index.rb' )
}
