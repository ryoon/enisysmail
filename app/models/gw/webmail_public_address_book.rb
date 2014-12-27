# coding: utf-8
class Gw::WebmailPublicAddressBook < ActiveRecord::Base
  include Sys::Model::Base
  include Sys::Model::Auth::Free

  # 編集部門、編集者
  has_many :editable_groups, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBookEditableGroup", dependent: :destroy
  has_many :editable_users, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBookEditableUser", dependent: :destroy
  # 閲覧部門、閲覧者
  has_many :readable_groups, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBookReadableGroup", dependent: :destroy
  has_many :readable_users, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBookReadableUser", dependent: :destroy

  # グループ
  has_many :groups, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressGroup", dependent: :destroy
  # アドレス
  has_many :addresses, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddress", dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: true
  validate :state_valid

  after_save :update_editable_groups, :update_editable_users,:update_readable_groups, :update_readable_users

  # === デフォルトのorder。
  #  名前の昇順
  #
  default_scope order("gw_webmail_public_address_books.name", "gw_webmail_public_address_books.id")

  # === 空のActiveRecord::Relationを返すスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ActiveRecord::Relation
  scope :none, limit(0)

  # === 状態が公開の共有アドレス帳を抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_opened, lambda {
    where(state: Gw::WebmailPublicAddressBook.opened_state_value)
  }

  # === 閲覧可能な共有アドレス帳を抽出するためのスコープ
  #
  # ==== 引数
  #  * target_user
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_readable, lambda { |target_user|
    # 管理権限があれば全共有アドレス帳が閲覧可能
    if target_user.public_address_book_admin_user?
      scoped
    else
      # 編集権限があれば、それも閲覧可能
      readable_book_ids_by_editable = Gw::WebmailPublicAddressBook.extract_editable(target_user).map(&:id)

      target_user_group_ids = target_user.enable_user_groups.map(&:group_id)
      target_user_group_ids << Sys::Group.no_limit_group_id

      # 閲覧権限しか無い場合は状態が公開のみ閲覧可能
      # 編集権限以上を持っていれば readable_book_ids_by_editable に book_id が含まれている
      search_base_relation = extract_opened.includes([:readable_groups, :readable_users])
      readable_book_ids_by_group = search_base_relation.where(
        "gw_webmail_public_address_book_readable_groups.group_id in (?)", target_user_group_ids).map(&:id)
      readable_book_ids_by_user = search_base_relation.where(
        "gw_webmail_public_address_book_readable_users.user_id = ?", target_user.id).map(&:id)

      target_book_ids = (readable_book_ids_by_editable + readable_book_ids_by_group + readable_book_ids_by_user).uniq.compact

      where(id: target_book_ids)
    end
  }

  # === 編集可能な共有アドレス帳を抽出するためのスコープ
  #
  # ==== 引数
  #  * target_user
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_editable, lambda { |target_user|
    # 管理権限があれば全共有アドレス帳が編集可能
    if target_user.public_address_book_admin_user?
      scoped
    else
      target_user_group_ids = target_user.enable_user_groups.map(&:group_id)
      target_user_group_ids << Sys::Group.no_limit_group_id

      search_base_relation = includes([:editable_groups, :editable_users])

      editable_book_ids_by_group = search_base_relation.where(
        "gw_webmail_public_address_book_editable_groups.group_id in (?)", target_user_group_ids).map(&:id)
      editable_book_ids_by_user = search_base_relation.where(
        "gw_webmail_public_address_book_editable_users.user_id = ?", target_user.id).map(&:id)

      target_book_ids = (editable_book_ids_by_group + editable_book_ids_by_user).uniq.compact

      where(id: target_book_ids)
    end
  }

  # === 削除(管理)可能な共有アドレス帳を抽出するためのスコープ
  #
  # ==== 引数
  #  * target_user
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_deletable, lambda { |target_user|
    if target_user.public_address_book_admin_user?
      scoped
    else
      none
    end
  }

  # === JSON形式の editable_groups_json から実体のレコードを更新する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_editable_groups
    self.editable_groups.destroy_all

    if self.editable_groups_json.present?
      target_groups = JSON.parse(self.editable_groups_json)
      target_groups.each do |target_group|
        target_group_id = target_group[1]

        # 制限なしの場合
        if Sys::Group.no_limit_group_id?(target_group_id)
          target_group = Sys::Group.no_limit_group
        else
          target_group = Sys::Group.where(id: target_group_id).first
        end

        Gw::WebmailPublicAddressBookEditableGroup.create!(
          public_address_book_id: self.id, group_id: target_group_id,
          group_code: target_group.code, group_name: target_group.name)
      end
    end
  end

  # === JSON形式の editable_users_json から実体のレコードを更新する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_editable_users
    self.editable_users.destroy_all

    if self.editable_users_json.present?
      target_users = JSON.parse(self.editable_users_json)
      target_users.each do |target_user|
        target_user_id = target_user[1]
        target_user = Sys::User.where(id: target_user_id).first

        Gw::WebmailPublicAddressBookEditableUser.create!(
          public_address_book_id: self.id, user_id: target_user_id,
          user_code: target_user.code, user_name: target_user.name)
      end
    end
  end

  # === JSON形式の readable_groups_json から実体のレコードを更新する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_readable_groups
    self.readable_groups.destroy_all

    if self.readable_groups_json.present?
      target_groups = JSON.parse(self.readable_groups_json)
      target_groups.each do |target_group|
        target_group_id = target_group[1]

        # 制限なしの場合
        if Sys::Group.no_limit_group_id?(target_group_id)
          target_group = Sys::Group.no_limit_group
        else
          target_group = Sys::Group.where(id: target_group_id).first
        end

        Gw::WebmailPublicAddressBookReadableGroup.create!(
          public_address_book_id: self.id, group_id: target_group_id,
          group_code: target_group.code, group_name: target_group.name)
      end
    end
  end

  # === JSON形式の readable_users_json から実体のレコードを更新する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_readable_users
    self.readable_users.destroy_all

    if self.readable_users_json.present?
      target_users = JSON.parse(self.readable_users_json)
      target_users.each do |target_user|
        target_user_id = target_user[1]
        target_user = Sys::User.where(id: target_user_id).first

        Gw::WebmailPublicAddressBookReadableUser.create!(
          public_address_book_id: self.id, user_id: target_user_id,
          user_code: target_user.code, user_name: target_user.name)
      end
    end
  end

  # === 状態の検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def state_valid
    validates_inclusion_of :state, in: Gw::WebmailPublicAddressBook.state_values
  end

  # === 共有アドレス帳を新規作成可能か評価するメソッド
  #  レコード作成前に評価される
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def creatable?
    return Core.user.public_address_book_admin_user?
  end

  # === 共有アドレス帳を編集可能か評価するメソッド
  #  レコード更新前に評価される
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def editable?
    return Core.user.public_address_book_editable_user?(self)
  end

  # === 共有アドレス帳を削除可能か評価するメソッド
  #  レコード削除前に評価される
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def deletable?
    return Core.user.public_address_book_admin_user?
  end

  # === root直下に属するグループを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  def root_groups
    return self.groups.extract_root
  end

  class << self

    # === 状態の選択肢を返すメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  [name, value]
    def states
      return I18n.t("rumi.public_address_book.states").map { |factor| factor.reverse }
    end

    # === 状態の値を返すメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  [value]
    def state_values
      return Gw::WebmailPublicAddressBook.states.map { |factor| factor.last }
    end

    # === 状態が公開の値を返すメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  1
    def opened_state_value
      return Gw::WebmailPublicAddressBook.state_values.first
    end

    # === 状態の表示名を返すメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  [name]
    def state_names
      return Gw::WebmailPublicAddressBook.states.map { |factor| factor.first }
    end

    # === 状態の値から表示名を返すメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  状態の表示名
    def state_show(state_value)
      return nil if state_value.blank?

      state_value_index = Gw::WebmailPublicAddressBook.state_values.index(state_value)
      return Gw::WebmailPublicAddressBook.state_names[state_value_index]
    end

  end

end
