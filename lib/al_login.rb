#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# alone : application framework for small embedded systems.
#               Copyright (c) 2009-2010 Inas Co Ltd. All Rights Reserved.
#
# This file is destributed under BSD License. Please read the COPYRIGHT file.
#
# ログインマネージャ
#
# (STRATEGY)
# requireされるだけで、動作開始する。
# セッション変数 al_user_idが設定されていれば、ログインしていると見なし、
# 設定されていなければ、ログインされていないと見なして、AL_LOGIN_URIに規定された
# ログイン画面のURIへリダイレクトする。

require 'al_session'


##
# ログインチェック
# 
# (note)
# ログインしていなければ、ログインURIへリダイレクトする
#
if ! AlSession[:al_user_id]
  Alone::redirect_to( AL_LOGIN_URI )
  AlSession[:al_request_uri] = Alone::request_uri()
end
