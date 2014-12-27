# -*- coding: utf-8 -*-
# === 公開アドレス帳管理権限機能用共通モジュール
#  Sys::User, Sys::Group にMix-inして使用する
module Sys::Model::Auth::PublicAddress
  extend ActiveSupport::Concern

  # === 管理権限機能において使用するデータを生成する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  変換データ(Array)
  def public_addr_data
    case self
    when Sys::Group
      [code, id, name]
    when Sys::User
      [account, id, "#{name}(#{account})"]
    end
  end

  # === 管理権限判定を行う
  #  当インスタンスが管理権限を持つか否か判定を行う。
  #  （上位グループに遡り判定）
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  真偽値(true/false)
  def has_public_addr_auth?
    auth = public_addr_auth
    case self
    when Sys::Group
      g = self.parent
    when Sys::User
      g = self.group
    end
    while(!auth && g) do
      auth |= g.public_addr_auth
      g = g.parent
    end
    return auth
  end

  # === クラスメソッド定義用モジュール
  module ClassMethods
    # === 管理権限レコード抽出メソッド
    #  管理権限を持つレコード(User, Group)を抽出する
    # === 引数
    #  * なし
    # === 戻り値
    #  抽出結果(ActiveRecord::Relation)
    def find_public_addr_auth
      where(public_addr_auth: true)
    end

    # === 管理権限更新メソッド
    #  管理権限の更新を行うメソッド
    # === 引数
    #  * json: クライアントからの送信データ(String)
    # === 戻り値
    #  なし
    def update_public_addr_auth(json)
      upd_proc = ->(r) {
        r.public_addr_auth ^= true
        r.save!
      }
      ids = JSON.parse(json).map {|elm| elm[1] }
      transaction {
        find_public_addr_auth.each(&upd_proc)
        where(id: ids).each(&upd_proc)
      }
    end
  end
end
