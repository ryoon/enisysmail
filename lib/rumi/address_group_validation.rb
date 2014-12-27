# coding: utf-8

# === アドレス帳グループの共通モジュール
#
module Rumi::AddressGroupValidation

  attr_accessor :call_update_children_level_no

  # === 自身と自身の親をディレクトリ表記で返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  パンくずリスト
  def to_directory_notation
    return (self.all_parents.map(&:name) << self.name).join(I18n.t("rumi.public_address_group.directory_notation"))
  end

  # === 自身の親を全て返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def all_parents(parents_array = [])
    # 親がrootグループでない場合
    if self.parent_id.present? && !self.parent_id.to_i.zero?
      target_parent = self.class.where(id: self.parent_id).first
      parents_array.unshift(target_parent)

      target_parent.all_parents(parents_array)
    end

    return parents_array
  end

  # === グループ名の特殊文字があるか評価するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def include_special_character?(str)
    return str.present? && str.to_s =~ /\/|;/
  end

  # === アドレス帳グループ名の検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def name_valid
    errors.add :name, :invalid if include_special_character?(self.name)

    # 親がrootグループでない場合
    if self.parent_id.present? && !self.parent_id.to_i.zero?
      target_parent = self.class.where(id: self.parent_id).first
      # 親グループと同じ名前か?
      self.errors.add :name, :same_parent_name if target_parent.present? && target_parent.name == self.name
    end
  end

  # === 子グループの階層レベル最適化メソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_children_level_no
    if self.call_update_children_level_no && self.level_no_changed?
      children_level_no = self.level_no.next
      self.children.each do |child_group|
        child_group.call_update_children_level_no = true
        child_group.level_no = children_level_no
        child_group.save(validate: false)
      end
    end
  end

end
