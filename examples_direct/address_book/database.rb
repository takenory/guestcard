# encoding: utf-8

require 'sequel'

file_name = 'data/addresses.db'

DB = Sequel.sqlite(file_name)

begin
  DB.schema(:addresses)
rescue
  DB.create_table :addresses do
    primary_key :id
    String :name
    String :mail
    String :zipcode
    String :address
    String :phone
  end
end

class Address < Sequel::Model
end
