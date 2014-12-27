# coding: utf-8
class Sys::PublicAddressBookRole < ActiveRecord::Base
  include Sys::Model::Base

  # 管理部門、管理者
  has_many :admin_groups, foreign_key: :public_address_book_role_id, class_name: "Sys::PublicAddressBookAdminGroup", dependent: :destroy
  has_many :admin_users, foreign_key: :public_address_book_role_id, class_name: "Sys::PublicAddressBookAdminUser", dependent: :destroy

  after_save :update_admin_groups, :update_admin_users

  # === JSON形式の admin_groups_json から実体のレコードを更新する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_admin_groups
    self.admin_groups.destroy_all

    if self.admin_groups_json.present?
      target_groups = JSON.parse(self.admin_groups_json)
      target_groups.each do |target_group|
        target_group_id = target_group[1]
        target_group = Sys::Group.where(id: target_group_id).first

        Sys::PublicAddressBookAdminGroup.create!(
          public_address_book_role_id: self.id, group_id: target_group_id,
          group_code: target_group.code, group_name: target_group.name)
      end
    end
  end

  # === JSON形式の admin_users_json から実体のレコードを更新する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_admin_users
    self.admin_users.destroy_all

    if self.admin_users_json.present?
      target_users = JSON.parse(self.admin_users_json)
      target_users.each do |target_user|
        target_user_id = target_user[1]
        target_user = Sys::User.where(id: target_user_id).first

        Sys::PublicAddressBookAdminUser.create!(
          public_address_book_role_id: self.id, user_id: target_user_id,
          user_code: target_user.code, user_name: target_user.name)
      end
    end
  end

  # === システム管理者か評価する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def creatable?
    return Core.user.system_admin?
  end
  
  # === システム管理者か評価する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def readable?
    return Core.user.system_admin?
  end
  
  # === システム管理者か評価する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def editable?
    return Core.user.system_admin?
  end
  
  # === システム管理者か評価する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def deletable?
    return Core.user.system_admin?
  end

  class << self

    # === 初めの1件を取得し、1件もなければ作成するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  Sys::PublicAddressBookRole
    def first_or_create
      role = Sys::PublicAddressBookRole.first
      role = Sys::PublicAddressBookRole.create! if role.blank?

      return role
    end
  end

end
