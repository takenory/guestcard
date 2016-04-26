#!/usr/bin/env ruby
# encoding: utf-8

require '../../lib/alone'
require './database'

def reject_request
  Alone::redirect_to('index.rb')
end

Alone::main() {
  @form = AlForm.new(
    AlHidden.new( 'id', :required => true,
                 :validator => /^\d+$/ ),
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


  if ENV['REQUEST_METHOD'] == 'GET'
    reject_request unless @form.validate([:id])
    @address = Address.find(:id => @form[:id])
    reject_request unless @address
    @address.values.each do |k, v|
      v.force_encoding('utf-8') if v.respond_to?('force_encoding')
    end
    @form.set_values( @address.values )
    AlTemplate.run('edit.html.erb')

  elsif ENV['REQUEST_METHOD'] == 'POST'
    if @form.validate()
      @address = Address.find(:id => @form[:id])
      reject_request unless @address
      @form.values.delete(:id)
      @address.update( @form.values )
      @address.save
      AlTemplate.run('show.html.erb')
    else
      AlTemplate.run('edit.html.erb')
    end

  else
    reject_request
  end
}
