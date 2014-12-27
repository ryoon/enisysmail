# coding: utf-8
class Gw::WebmailPublicAddress < ActiveRecord::Base
  include Sys::Model::Base
  include Sys::Model::Auth::Free

  include Rumi::AddressImportor
  include Rumi::AddressExportor

  # Ajaxからの登録を判別するための項目
  attr_accessor :easy_entry, :copy_private_address_id

  # 共有アドレス帳
  belongs_to :public_address_book, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBook"
  # 所属グループ
  has_many :affiliated_groups, foreign_key: :address_id, class_name: "Gw::WebmailPublicAffiliatedAddressGroup", dependent: :destroy
  accepts_nested_attributes_for :affiliated_groups, allow_destroy: true, reject_if: :reject_affiliated_groups
  has_many :groups, through: :affiliated_groups, class_name: "Gw::WebmailPublicAddressGroup"

  before_validation :escape_name_and_kana, :set_state_on_easy_entry, :copy_private_address_info_on_easy_entry
  validates :name, :email, presence: true
  validate :state_valid
  validate :public_address_book_valid
  validate :email_valid_on_easy_entry
  validate :email_valid_on_update

  # === 共有アドレス帳個人設定の並び順
  #
  # ==== 引数
  #  * target_user
  # ==== 戻り値
  #  並び替え後の結果(ActiveRecord::Relation)
  scope :order_user_setting, lambda { |target_user|
    # public_address_order #=> email, kana, sort_no
    if target_user.public_address_order.blank?
      order("gw_webmail_public_addresses.email", "gw_webmail_public_addresses.id")
    else
      order("gw_webmail_public_addresses.#{target_user.public_address_order}", "gw_webmail_public_addresses.id")
    end
  }

  # === CSVインポート時に更新対象の連絡先用の並び順
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  並び替え後の結果(ActiveRecord::Relation)
  scope :order_import_update_target, order("gw_webmail_public_addresses.id")

  # === メールアドレスでアドレスを抽出(LIKE)するためのスコープ
  #
  # ==== 引数
  #  * email_values
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :search_emails, lambda { |email_values|
    search_results = scoped
    email_values.to_s.split(/[ 　]+/).each do |email_value|
      search_results = search_results.search_email(email_value) if email_value.present?
    end

    search_results
  }

  # === メールアドレスでアドレスを抽出(LIKE)するためのスコープ
  #
  # ==== 引数
  #  * email_value
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :search_email, lambda { |email_value|
    public_address_table = Gw::WebmailPublicAddress.arel_table

    where(public_address_table[:email].matches("%#{email_value}%"))
  }

  # === 名前、または、かなでアドレスを抽出(LIKE)するためのスコープ
  #
  # ==== 引数
  #  * name_or_kana_values
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :search_name_or_kanas, lambda { |name_or_kana_values|
    search_results = scoped
    name_or_kana_values.to_s.split(/[ 　]+/).each do |name_or_kana_value|
      search_results = search_results.search_name_or_kana(name_or_kana_value) if name_or_kana_value.present?
    end

    search_results
  }

  # === 名前、または、かなでアドレスを抽出(LIKE)するためのスコープ
  #
  # ==== 引数
  #  * name_or_kana_value
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :search_name_or_kana, lambda { |name_or_kana_value|
    escaped_name_or_kana_value = Gw::WebmailPublicAddress.escape_kana_character(name_or_kana_value)
    public_address_table = Gw::WebmailPublicAddress.arel_table

    where(public_address_table[:name].matches("%#{name_or_kana_value}%").or(
      public_address_table[:kana].matches("%#{escaped_name_or_kana_value}%")))
  }

  # === メールアドレスが空のアドレス除くためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_email_blank, lambda {
    public_address_table = Gw::WebmailPublicAddress.arel_table

    where(public_address_table[:email].not_eq(nil).or(
      public_address_table[:email].not_eq("")))
  }

  # === 状態が公開の共有アドレスを抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_opened, lambda {
    where(state: Gw::WebmailPublicAddressBook.opened_state_value)
  }

  # === 閲覧可能な共有アドレスを抽出するためのスコープ
  #
  # ==== 引数
  #  * target_user
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_readable, lambda { |target_user|
    # 管理権限があれば全共有アドレスが閲覧可能
    if target_user.public_address_book_admin_user?
      scoped.order_user_setting(target_user)
    else
      # 編集権限がある共有アドレス帳であれば状態に左右されない
      editable_book_ids = Gw::WebmailPublicAddressBook.extract_editable(target_user).map(&:id)
      editable_address_ids = Gw::WebmailPublicAddress.where(public_address_book_id: editable_book_ids).map(&:id)
      # 編集権限以上持つのであればアドレスの状態は公開のみ
      readable_book_ids = Gw::WebmailPublicAddressBook.extract_readable(target_user).map(&:id)
      readable_address_ids = Gw::WebmailPublicAddress.where(public_address_book_id: readable_book_ids).extract_opened.map(&:id)

      where(id: (editable_address_ids + readable_address_ids).uniq.compact).order_user_setting(target_user)
    end
  }

  # === 状態の検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def state_valid
    validates_inclusion_of :state, in: Gw::WebmailPublicAddressBook.state_values
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

  # === 名前、名前フリガナの特殊文字をエスケープするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def escape_name_and_kana
    self.name = Gw::WebmailPublicAddress.escape_special_character(name)

    self.kana = Gw::WebmailPublicAddress.escape_kana_character(kana)
    self.company_kana = Gw::WebmailPublicAddress.escape_kana_character(company_kana)
  end

  # === Ajaxからの登録処理において状態を公開にするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_state_on_easy_entry
    self.state = Gw::WebmailPublicAddressBook.opened_state_value if self.easy_entry
  end

  # === Ajaxからの登録処理におけるメールアドレスの検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def email_valid_on_easy_entry
    if self.easy_entry && self.email.present? && self.name.present? && self.public_address_book.present?
      # 連絡先登録は編集権限以上のユーザーが実行できるので.addresses.extract_readable(Core.user)は不要
      if public_address_book.addresses.where(email: self.email).exists?
        errors.add :base, I18n.t("rumi.operation.add_public_address.message.errors.base")
      end
    end
  end

  # === Ajaxからの登録処理において個人アドレス帳からの場合は個人アドレスの情報をコピーするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def copy_private_address_info_on_easy_entry
    if self.easy_entry
      copy_private_address = Gw::WebmailAddress.where(
        user_id: Core.user.id, id: self.copy_private_address_id).first

      if copy_private_address.present?
        self.sort_no = copy_private_address.sort_no
        self.uri = copy_private_address.uri
        self.tel = copy_private_address.tel
        self.fax = copy_private_address.fax
        self.zip_code = copy_private_address.zip_code
        self.address = copy_private_address.address
        self.mobile_tel = copy_private_address.mobile_tel
        self.memo = copy_private_address.memo
        self.official_position = copy_private_address.official_position
        self.company_name = copy_private_address.company_name
        self.company_kana = copy_private_address.company_kana
        self.company_tel = copy_private_address.company_tel
        self.company_fax = copy_private_address.company_fax
        self.company_zip_code = copy_private_address.company_zip_code
        self.company_address = copy_private_address.company_address
      end
    end
  end

  # === 新規作成、編集でチェックされなかった所属グループのインスタンスを破棄するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def reject_affiliated_groups(group_attributes)
    group_attributes["group_id"].blank?
  end

  # === 新規作成、編集でチェックされなかった所属グループのインスタンスを生成するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Gw::WebmailPublicAffiliatedAddressGroup
  def find_or_build_affiliated_group(group)
    return self.affiliated_groups.to_a.select { |affiliated_group| affiliated_group.group_id == group.id }.first ||
      self.affiliated_groups.build(provisional_group: group)
  end

  # === メール作成画面で表示するアドレスと名前を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  アドレスと名前
  def display_name
    return "#{self.name} <#{self.email}>"
  end

  # === CSVインポート確認画面で重複表示するためのアドレスのインスタンスを作成するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_provisional_exist_address
    # CSVインポートは編集権限以上のユーザーが実行できるので.addresses.extract_readable(Core.user)は不要
    self.provisional_exist_address = self.public_address_book.addresses.where(email: self.email).first
  end

  class << self

    # === 名前の特殊文字をエスケープするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  エスケープした文字列
    def escape_special_character(str)
      return str.to_s.gsub(/["<>]/, "")
    end

    # === 名前の特殊文字をエスケープするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  エスケープした文字列
    def escape_kana_character(str)
      return str.to_s.tr("ぁ-ん", "ァ-ン")
    end

    # === アドレス帳グループに対し抽出結果の1件を取得する、1件もなければインスタンスを生成するメソッド
    #
    # ==== 引数
    #  * target_name: 抽出対象のグループ名
    #  * target_level_no: 抽出対象の階層レベル
    #  * target_all_parent_names: 抽出対象のグループを含めた親グループ名
    #  * book: 共有アドレス帳
    # ==== 戻り値
    #  Gw::WebmailPublicAddressGroup
    def group_first_or_new(target_name, target_level_no, target_all_parent_names, book)
      extract_target_groups = book.groups
      result_extract = self.group_first_and_parent_id_from_import_csv(
        extract_target_groups, target_level_no, target_all_parent_names)

      # 共有アドレス帳の最上位(root)グループのIDはnil
      parent_group_id = result_extract[:parent_group_id]
      target_group = result_extract[:target_group]

      target_group = Gw::WebmailPublicAddressGroup.new(public_address_book_id: book.id,
        name: target_name, level_no: target_level_no, parent_id: parent_group_id) if target_group.blank?

      return target_group
    end

  end

end
