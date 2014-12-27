# coding: utf-8
class Gw::WebmailPublicAddressBookReadableUser < ActiveRecord::Base
  include Sys::Model::Base

  # 共有アドレス帳
  belongs_to :public_address_book, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBook"
  # ユーザー
  belongs_to :user, foreign_key: :user_id, class_name: "Sys::User"
end
