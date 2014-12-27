class Sys::AddressSetting < ActiveRecord::Base
  include Sys::Model::Base
  include Sys::Model::Base::Page
  #include Sys::Model::Rel::Unid
  #include Sys::Model::Rel::Creator
  include Sys::Model::Auth::Manager
  
  validates_presence_of :key_name, :sort_no, :used, :list_view

  # === アドレス帳閲覧、新規作成、編集で使用する項目のみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_used_address_item, where(used: "1").order(:sort_no, :id)

  # === アドレス一覧画面で表示する項目のみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_list_view_address_item, where(list_view: "1").order(:sort_no, :id)

  # === 個人アドレス帳に不必要な項目を除外するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_state, lambda {
    a_t = Sys::AddressSetting.arel_table

    where(a_t[:key_name].not_eq("state"))
  }

  class << self

    # === テキストエリア編集を必要とする項目か評価するメソッド
    #
    # ==== 引数
    #  * key_name: 項目名
    # ==== 戻り値
    #  boolean
    def text_area_items?(key_name)
      return [
        "address", "memo", "company_address"
      ].include?(key_name)
    end

    # === 項目: グループか評価するメソッド
    #
    # ==== 引数
    #  * key_name: 項目名
    # ==== 戻り値
    #  boolean
    def affiliated_group_items?(key_name)
      return [
        "group_id"
      ].include?(key_name)
    end

    # === 項目: 状態か評価するメソッド
    #
    # ==== 引数
    #  * key_name: 項目名
    # ==== 戻り値
    #  boolean
    def state_items?(key_name)
      return [
        "state"
      ].include?(key_name)
    end

    # === 項目: 名前か評価するメソッド
    #
    # ==== 引数
    #  * key_name: 項目名
    # ==== 戻り値
    #  boolean
    def name_items?(key_name)
      return [
        "name"
      ].include?(key_name)
    end

    # === 必須項目か評価するメソッド
    #
    # ==== 引数
    #  * key_name: 項目名
    # ==== 戻り値
    #  boolean
    def presence_items?(key_name)
      return [
        "name", "email"
      ].include?(key_name)
    end

  end

end
