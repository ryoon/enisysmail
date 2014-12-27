# coding: utf-8
class Gw::WebmailPublicAffiliatedAddressGroup < ActiveRecord::Base
  include Sys::Model::Base

  # 共有アドレス帳
  belongs_to :public_address_book, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBook"
  # 所属グループ
  belongs_to :group, foreign_key: :group_id, class_name: "Gw::WebmailPublicAddressGroup"
  # アドレス
  belongs_to :address, foreign_key: :address_id, class_name: "Gw::WebmailPublicAddress"

  # 新規作成時の場合使用する、仮のグループ情報を保持する
  attr_accessor :provisional_group

  before_validation :set_public_address_book
  validate :public_address_book_valid

  # === 属する共有アドレス帳をセットするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_public_address_book
    self.public_address_book_id = self.group.public_address_book_id if self.group.present?
  end

  # === 編集可能な共有アドレス帳の検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def public_address_book_valid
    validates_inclusion_of :public_address_book_id,
      in: Gw::WebmailPublicAddressBook.extract_editable(Core.user).map(&:id)
  end

  # === 新規作成、編集でチェックされたか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def checked?
    return self.group.present? && !self._destroy
  end

end
