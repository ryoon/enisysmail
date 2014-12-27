# coding: utf-8
class Sys::PublicAddressBookAdminGroup < ActiveRecord::Base
  include Sys::Model::Base

  # 共有アドレス帳管理権限
  belongs_to :public_address_book_role, foreign_key: :public_address_book_role_id, class_name: "Sys::PublicAddressBookRole"
  # グループ
  belongs_to :group, foreign_key: :group_id, class_name: "Sys::Group"
end
