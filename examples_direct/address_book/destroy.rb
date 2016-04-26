#!/usr/bin/env ruby
# encoding: utf-8

require '../../lib/alone'
require './database'

def reject_request
  Alone::redirect_to('index.rb')
end

Alone::main() {
  @form = AlForm.new( AlInteger.new( "id", :required => true) )

  if ENV['REQUEST_METHOD'] == 'GET'
    reject_request unless @form.validate()
    @address = Address.find(:id => @form[:id])
    reject_request unless @address
    @address.values.each do |k, v|
      v.force_encoding('utf-8') if v.respond_to?('force_encoding')
    end
    AlTemplate.run('destroy.html.erb')

  elsif ENV['REQUEST_METHOD'] == 'POST'
    reject_request unless @form.validate()
    @address = Address.find(:id => @form[:id])
    @address.destroy
    Alone::redirect_to('index.rb')

  else
    reject_request
  end
}
