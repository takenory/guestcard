#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#

require '../../lib/alone'

Alone::main() {
  @now = Time.now
  AlSession['reload_count'] = AlSession['reload_count'].to_i + 1
  AlTemplate.run( 'index.rhtml' )
  AlSession['visit_before'] = @now
}
