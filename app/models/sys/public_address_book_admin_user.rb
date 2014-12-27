# coding: utf-8
class Sys::PublicAddressBookAdminUser < ActiveRecord::Base
  include Sys::Model::Base

  # 共有アドレス帳管理権限
  belongs_to :public_address_book_role, foreign_key: :public_address_book_role_id, class_name: "Sys::PublicAddressBookRole"
  # ユーザー
  belongs_to :user, foreign_key: :user_id, class_name: "Sys::User"
end
