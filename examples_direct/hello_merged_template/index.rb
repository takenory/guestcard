#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'

Alone::main() {
  @my_message = "Hello world"
  html_template = <<END
<%= header_section %>
  <title>Test</title>
<%= body_section %>
  <p><%=h @my_message %></p>
<%= footer_section %>
END

  template = AlTemplate.run_str( html_template )
}
