#!/usr/bin/env ruby
# encoding: utf-8

require '../../lib/alone'
require './database'

Alone::main() {
  @form = AlForm.new(
    AlText.new( 'name', :label => '名前', 
               :required => true ),
    AlMail.new( 'mail', :label => 'メールアドレス', 
               :required => true ),
    AlText.new( 'zipcode', :label => '郵便番号', 
               :required => true, :validator => /^\d{3}-?\d{4}$/ ),
    AlText.new( 'address', :label => '住所', 
               :required => true ),
    AlText.new( 'phone', :label => '電話番号', 
               :required => true, :validator => /^\d[\d-]+\d$/ ),

    AlSubmit.new( 'submit', :value => '登録')
  )

  if @form.validate
    @address = Address.new( @form.values )
    @address.save
    AlTemplate.run('show.html.erb')
  else
    AlTemplate.run('new.html.erb')
  end
}
