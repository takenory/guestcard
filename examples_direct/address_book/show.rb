#!/usr/bin/env ruby
# encoding: utf-8

require '../../lib/alone'
require './database'

Alone::main() {
  @form = AlForm.new( AlInteger.new("id", :required => true) )

  if @form.validate
    @address = Address.find(:id => @form[:id])
    Alone::redirect_to('index.rb') unless @address
    AlTemplate.run('show.html.erb')
  else
    Alone::redirect_to('index.rb')
  end
}
