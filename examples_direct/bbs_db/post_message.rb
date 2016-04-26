#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require '../../lib/alone'
require './bbs_store'


def save_message( form )
  
  db = BbsStore.open
  messages = db[:messages]
  messages.insert(
    :name => form["namae"],
    :message => form["message"],
    :created_at => Time.now)
end

Alone::main() {
  @form = AlForm.new
  @form.set_widgets(
    AlText.new( "namae", :label=>"お名前", :required=>true,
                :value=>AlSession["namae"] ),
    AlTextArea.new( :"message", :label=>"メッセージ", :required=>true ),
    AlSubmit.new( "submit", :value=>"決定", :style=>"float: right;" )
  )


  if ! @form.fetch_request() || ! @form.validate()
    AlTemplate.run( 'input_form.rhtml' )
  else
    save_message( @form )
    AlSession["namae"] = @form["namae"]
    AlTemplate.run( 'commit.rhtml' )
  end
}
