# coding: utf-8
class Gw::WebmailPublicAddressGroup < ActiveRecord::Base
  include Sys::Model::Base
  include Sys::Model::Auth::Free

  include Rumi::AddressGroupValidation

  # 共有アドレス帳
  belongs_to :public_address_book, foreign_key: :public_address_book_id, class_name: "Gw::WebmailPublicAddressBook"
  # 親グループ
  belongs_to :parent, foreign_key: :parent_id, class_name: "Gw::WebmailPublicAddressGroup"
  # 子グループ
  has_many :children, foreign_key: :parent_id, class_name: "Gw::WebmailPublicAddressGroup", dependent: :destroy
  # アドレス
  has_many :affiliated_addresses, foreign_key: :group_id, class_name: "Gw::WebmailPublicAffiliatedAddressGroup", dependent: :destroy
  has_many :addresses, through: :affiliated_addresses, class_name: "Gw::WebmailPublicAddress"

  after_save :update_children_level_no

  validates :name, presence: true
  validate :name_valid
  # 共有アドレス帳毎で同一親グループ配下のグループ名は重複を許可しない
  validates :name, uniqueness: { scope: [:public_address_book_id, :parent_id] }
  validate :parent_valid
  validate :public_address_book_valid

  # === デフォルトのorder。
  #  名前の昇順
  #
  default_scope order("gw_webmail_public_address_groups.name", "gw_webmail_public_address_groups.id")

  # === 親グループから階層レベルをセットするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #
  def set_level_no_from_parent
    if self.parent_id.blank?
      self.level_no = 1
    else
      self.level_no = self.parent.level_no.next
    end

    self.call_update_children_level_no = self.level_no_changed?
  end

  # === 親グループの検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def parent_valid
    # 親グループがルート以外の時検証する
    if self.parent_id.present?
      without_group = nil
      without_group = self if self.persisted?
      parent_ids = Gw::WebmailPublicAddressGroup.sorted_address_groups(
        self.public_address_book.groups, without_group).map(&:id)

      validates_inclusion_of :parent_id, in: parent_ids
    end
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

  # === 階層レベル1のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_root, where(parent_id: nil)

  # === 引数のグループ以外を抽出するためのスコープ
  #
  # ==== 引数
  #  * target_groups
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_target_groups, lambda { |target_groups|
    where("gw_webmail_public_address_groups.id not in (?)", target_groups.map(&:id))
  }

  # === 自身の選択肢を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  [name, value]
  def to_select_option
    return [[indented_space, self.name].join.html_safe, self.id]
  end

  # === 自身の階層レベルからインデントを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  インデント
  def indented_space
    indent_level = (self.level_no - 1) * 4
    return (I18n.t("rumi.public_address_group.indented") * indent_level).html_safe
  end

  # === 自身と自身の親をパンくずリストで返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  パンくずリスト
  def to_breadcrumbs_list
    return (self.all_parents.map(&:name) << self.name).join(I18n.t("rumi.public_address_group.breadcrumbs_list"))
  end

  class << self

    # === 階層レベル毎に並び替えたグループを返す
    #
    # ==== 引数
    #  * groups: Gw::WebmailPublicAddressGroup
    #  * without_groups: Gw::WebmailPublicAddressGroup
    #  * with_without_child: boolean
    # ==== 戻り値
    #  配列
    def sorted_address_groups(groups, without_groups = nil, with_without_child = true)
      parent_ids = groups.map(&:id)
      without_group_ids = []
      if without_groups.present?
        # 単体の場合
        if without_groups.is_a?(Gw::WebmailPublicAddressGroup)
          without_group_ids << without_groups.id
        # 複数の場合
        else
          without_group_ids = without_groups.to_a.map(&:id)
        end
      end

      base_groups = Gw::WebmailPublicAddressGroup.where(id: parent_ids)

      sorted_address_groups_array = []

      # 再帰的に処理するためメソッドを定義
      build_sorted_address_groups_method = lambda { |target_groups|
        target_groups.each do |target_group|
          is_without_group = without_group_ids.include?(target_group.id)
          sorted_address_groups_array << target_group unless is_without_group

          # without_group配下のグループも抽出する場合
          unless with_without_child && is_without_group
            # 子グループかつwithout_groupを考慮するとbase_groupsからの抽出となる
            child_groups = base_groups.where(parent_id: target_group.id) 
            build_sorted_address_groups_method.call(child_groups)
          end
        end
      }

      build_sorted_address_groups_method.call(base_groups.extract_root)

      return sorted_address_groups_array.flatten.compact
    end
  end

end
