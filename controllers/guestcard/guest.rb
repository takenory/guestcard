# coding: utf-8
# 来場者記録
#  ゲストモデル

DSN = "dbname=guestcard user=guestcard"

require "al_persist_postgres"

class Guest < AlPersistPostgres

  ##
  # initialize
  #
  def initialize()
    super( AlRdbw.connect( DSN ), "guests", "id" )
  end


end
