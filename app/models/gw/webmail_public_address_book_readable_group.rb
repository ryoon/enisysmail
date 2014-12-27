# coding: utf-8
class Gw::WebmailPublicAddressBookReadableGroup < ActiveRecord::Base
  include Sys::Model::Base

  # 共有アドレス帳
  belongs_to :public_address_book, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBook"

  # === 制限なしを考慮したgroupモデルの取得メソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Sys::Group
  def group
    if Sys::Group.no_limit_group_id?(self.group_id)
      return Sys::Group.no_limit_group
    else
      return Sys::Group.where(id: self.group_id).first
    end
  end

end
