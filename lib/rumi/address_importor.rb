# coding: utf-8
require "nkf"
require "csv"

# === アドレス帳へのインポート共通モジュール
#
module Rumi::AddressImportor
  # includeされた時にクラスメソッドも追加する
  extend ActiveSupport::Concern

  attr_accessor :provisional_exist_address, :provisional_affiliated_group_names,
    :provisional_affiliated_groups, :provisional_new_groups, :provisional_exist_groups

  # === メールアドレスの検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def email_valid_on_update
    validates_format_of :email, with: /\A[a-z0-9!#\$%&'\*\+\-\/=\?\^_`\{\|\}~\.]+@[a-z0-9\-\.]+\Z/i
  end

  # === CSVインポート時に必要な初期化を行うメソッド
  #
  # ==== 引数
  #  * book: 共有アドレス帳
  # ==== 戻り値
  #  なし
  def set_book_id_or_user_id_on_import_csv(book = nil)
    # 共有アドレス帳の場合
    if book.present?
      self.public_address_book_id = book.id
      # 状態を公開
      self.state = Gw::WebmailPublicAddressBook.opened_state_value
    # 個人アドレス帳の場合
    else
      self.user_id = Core.user.id
    end
  end

  # === CSVインポート確認画面で表示するための1連絡先に対するグループのインスタンスを作成するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_provisional_affiliated_groups
    # 仮の所属グループ
    #   e.g. [ [GroupA, GroupB, GroupC], [GroupD] ]
    self.provisional_affiliated_groups = []
    # 仮の所属グループで作成するグループ
    #   e.g. [ [GroupA, GroupB, GroupC] ]
    self.provisional_new_groups = []
    # 仮の所属グループで存在するグループ
    #   e.g. [ [GroupD] ]
    self.provisional_exist_groups = []

    # グループ区切り文字で分割し、1グループ毎に処理を実行する
    #   e.g. グループA/グループB/グループC;グループD
    #        #=> ["グループA/グループB/グループC", "グループD"]
    target_group_names = self.class.split_semicolon(self.provisional_affiliated_group_names)
    # グループ毎に、存在するグループか作成(追加)するグループが含まれているか確認する
    target_group_names.each do |target_group_name|
      self.new_provisional_affiliated_group(target_group_name)
    end
  end

  # === グループ指定から仮のグループ情報を作成する
  #  併せて、作成(追加)するグループ等も振り分ける
  # ==== 引数
  #  * target_group_names: グループ郡の文字列
  #      e.g. "グループA/グループB/グループC"
  # ==== 戻り値
  #  なし
  def new_provisional_affiliated_group(target_group_names)
    # 所属グループの親グループを含めた配列
    target_groups = []
    # 共有アドレス帳をセット
    if self.respond_to?(:public_address_book)
      book = self.public_address_book
    else
      book = nil
    end

    # グループ郡の文字列を区切り文字で分割する
    #   e.g. "グループA/グループB/グループC"
    #        #=> ["グループA", "グループB", "グループC"]
    target_group_names = self.class.split_directory_notation(target_group_names)
    target_group_names.each_with_index do |target_group_name, i|
      # 各アドレス帳のグループを検索し、Modelのインスタンスを格納する
      target_groups << self.class.group_first_or_new(target_group_name, i + 1, target_group_names, book)
    end

    # 仮の所属グループ名が適切な場合
    if self.class.provisional_group_name_valid?(target_groups)
      # 作成するグループが含まれている
      if target_groups.any? { |target_group| target_group.new_record? }
        self.provisional_new_groups << target_groups
      # 既存のグループのみ
      else
        self.provisional_exist_groups << target_groups
      end
      # 仮の所属グループ
      self.provisional_affiliated_groups << target_groups
    end

  end

  # === クラスメソッド定義用モジュール
  module ClassMethods

    # === CSVインポート確認画面で表示するためのアドレス、グループのインスタンスを作成するメソッド
    #
    # ==== 引数
    #  * csv_form: RumiHelper::CsvForm
    #  * book: Gw::WebmailPublicAddressBook
    # ==== 戻り値
    #  { valid_addresses: インポートできるアドレス, invalid_addresses: インポートできないアドレス, new_groups: 作成するグループ }
    def candidate_import_csv(csv_form, book = nil)
      csv_format_type = csv_form.format_type
      # インポートできるアドレス
      valid_addresses = []
      # インポートできないアドレス
      invalid_addresses = []
      # 作成するグループ
      new_groups = []

      # 変換後の文字列はUTF-8、改行コードLFで片仮名は半角から全角へ変換しない
      csv_string = NKF::nkf("-m0 -wx -Lu", csv_form.file.read)
      CSV.parse(csv_string, headers: true) do |row|
        # 空の行は無視する
        next if row.blank?

        address = self.new_from_csv(row, csv_format_type)
        address.set_book_id_or_user_id_on_import_csv(book)

        if address.valid?
          valid_addresses << address
          # 重複の有無をセット
          address.set_provisional_exist_address
          # 仮の所属グループ、作成するグループ、存在するグループをセット
          address.set_provisional_affiliated_groups
          # 作成するグループを含む仮の所属グループを集計
          new_groups.concat(address.provisional_new_groups)
        else
          invalid_addresses << address
        end
      end

      new_groups = self.new_groups_uniq_and_compact(new_groups)

      return {
        valid_addresses: valid_addresses,
        invalid_addresses: invalid_addresses,
        new_groups: new_groups
      }
    end

    # === CSVインポート確認画面で表示するためのアドレスのインスタンスを作成するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  Gw::WebmailAddress/Gw::WebmailPublicAddress
    def new_from_csv(row, csv_format_type)
      csv_hash_row = {}
      csv_header_key = "rumi.attributes.#{csv_format_type}.import"
      I18n.t(csv_header_key).each do |attr_key, name_or_key|
        row_name_or_hash = I18n.t([csv_header_key, attr_key].join("."))

        # 自宅/勤務先の住所
        if row_name_or_hash.is_a?(Hash)
          value = ""
          row_name_or_hash.each { |key, name| value << row[name].to_s }
        else
          value = row[row_name_or_hash]
        end

        attr_key = :provisional_affiliated_group_names if attr_key == :affliated_group_names

        csv_hash_row.store(attr_key, value)
      end

      return self.new(csv_hash_row)
    end

    # === グループ指定を表示する時に区切り文字でグループ名を分割するメソッド
    #
    # ==== 引数
    #  * target_group_names: グループ指定
    # ==== 戻り値
    #  配列
    def split_semicolon(target_group_names)
      return target_group_names.to_s.split(I18n.t("rumi.public_address_group.delimiter"))
    end

    # === グループ階層を表すセパレーターでグループ名を分割するメソッド
    #
    # ==== 引数
    #  * target_group_names: グループ指定
    # ==== 戻り値
    #  配列
    def split_directory_notation(target_group_names)
      return target_group_names.to_s.split(I18n.t("rumi.public_address_group.directory_notation"))
    end

    # === 作成するグループの重複削除と並び替えを行うメソッド
    #
    # ==== 引数
    #  * new_groups: [[Gw::WebmailAddressGroup/Gw::WebmailPublicAddressGroup, ...], ...]
    # ==== 戻り値
    #  配列: [[Gw::WebmailAddressGroup/Gw::WebmailPublicAddressGroup, ...], ...]
    def new_groups_uniq_and_compact(new_groups)
      return [] if new_groups.blank?
      # 空でないものを残す
      new_groups = new_groups.select { |new_group| new_group.present? }
      # グループ名での重複削除
      new_group_names = new_groups.map { |new_group| new_group.map(&:name) }
      new_group_names.uniq!
      # グループ名で検索し、置き換える
      new_groups = new_group_names.map do |new_group_name|
        new_groups.find { |new_group| new_group.map(&:name) == new_group_name }
      end

      # 親グループに作成するグループが含まれている場合もあるため、ここで追加する
      new_groups.clone.each do |new_group|
        last_new_group_index = new_group.find_index(new_group.last)
        new_group.each_with_index do |new_group_factor, i|
          # 既存グループはSkipする
          next if new_group_factor.persisted?
          # 最後の要素(所属グループ自体)が作成するグループの場合はSkip
          next if last_new_group_index == i

          # 作成するグループの候補を作成
          candidate_new_group = new_group.clone.slice(0, i + 1)
          # 他のグループ情報に含まれている場合はSkip
          next if new_group_names.any? { |new_group_name| new_group_name == candidate_new_group.map(&:name) }
          # グループの候補が適切か判断するメソッド
          if self.provisional_group_name_valid?(candidate_new_group)
            # 追加の作成するグループがあった場合は作成するグループに追加する
            new_groups << candidate_new_group
            new_group_names << candidate_new_group.map(&:name)
          end

        end
      end

      # グループ名での並び替え
      new_group_names.sort_by! do |new_group_name|
        new_group_name.join(I18n.t("rumi.public_address_group.directory_notation"))
      end
      # グループ名で検索し、置き換える
      new_groups = new_group_names.map do |new_group_name|
        new_groups.find { |new_group| new_group.map(&:name) == new_group_name }
      end

      return new_groups
    end

    # === グループ指定から作成した仮のグループ情報が適切か判断するメソッド
    #  self.class.new_provisional_affiliated_group 内で実行される
    # ==== 引数
    #  * target_group_names: グループ指定から作成した仮のグループ情報で作成(追加)するグループを含むもののみ
    #      e.g. [GroupA, GroupB, GroupC]
    # ==== 戻り値
    #  boolean
    def provisional_group_name_valid?(target_groups)
      # 仮に空の場合は検証NGと判断する
      return false if target_groups.blank?
      # 全て既存のグループであれば検証OKと判断する
      return true if target_groups.all? { |target_group| target_group.persisted? }

      # 作成するグループに対して検証を行う
      valid_result = true
      target_groups.each_with_index do |target_group, i|
        # 既存のグループはSkip
        next if target_group.persisted?

        # グループ名が空でないこと
        valid_result = false if target_group.name.blank?
        # グループ名に特殊文字が含まれていないこと
        valid_result = false if target_group.include_special_character?(target_group.name)
        # 親グループ名と同じでないこと
        target_parent_index = i - 1
        if target_parent_index >= 0
          target_parent = target_groups.fetch(target_parent_index, nil)
          valid_result = false if target_parent.present? && target_parent.name == target_group.name
        end

        # 検証NGがあった場合
        break unless valid_result
      end

      return valid_result
    end

    # === アドレス帳グループの親グループIDを取得するメソッド
    #
    # ==== 引数
    #  * extract_target_groups: 抽出対象のグループ郡
    #  * target_level_no: 抽出対象の階層レベル
    #  * target_all_parent_names: 抽出対象のグループを含めた親グループ名
    # ==== 戻り値
    #  { parent_group_id: 親グループID/nil, target_group: 抽出対象のグループ/nil }
    def group_first_and_parent_id_from_import_csv(extract_target_groups, target_level_no, target_all_parent_names)
      target_group = nil
      parent_group = nil

      target_all_parent_names.each_with_index do |parent_name, i|
        parent_level_no = i + 1
        target_group = extract_target_groups.where(name: parent_name, level_no: parent_level_no).first
        break if parent_level_no == target_level_no || target_group.blank?
        parent_group = target_group
        extract_target_groups = target_group.children
      end

      parent_group_id = nil
      parent_group_id = parent_group.id if parent_group.present?

      return { parent_group_id: parent_group_id, target_group: target_group }
    end

    # === CSVインポート確認画面で表示したアドレス、グループ情報をインポートするメソッド
    #
    # ==== 引数
    #  * candidate_data: アドレス、グループ情報のHash
    #  * csv_form: RumiHelper::CsvForm
    #  * book: Gw::WebmailPublicAddressBook
    # ==== 戻り値
    #  なし
    def import_csv(candidate_data, csv_form, book = nil)
      # 作成するグループ情報は縁sys用の場合でも作成するグループがなければフォームの送信Keyは存在しない
      new_groups = (candidate_data[:new_groups] || {}).values
      # CSVの形式がWindows Essentials用であれば項目:グループ指定が無いため作成するグループ情報を初期化する
      new_groups = [] if csv_form.format_win_ms?

      # インポートできるアドレスが無い場合も考慮する
      importable_addresses = (candidate_data[:importable_addresses] || {}).values
      # インポート可能な項目以外があればエラーとする
      allow_keys = I18n.t("rumi.attributes.#{csv_form.format_type}.import").keys
      importable_addresses.each do |importable_address|
        # 許可しない項目 = フォームの送信値(affliated_group_namesが無い場合もある) - 許可する項目
        not_allow_keys = importable_address.symbolize_keys.keys - allow_keys
        raise "importable_addresses has not_allow_keys" if not_allow_keys.present?
      end

      # アドレス、グループ情報をインポート
      ActiveRecord::Base.transaction do
        # 作成するグループ
        new_groups.each do |new_group|
          target_all_parent_names = self.split_directory_notation(
            new_group.delete(:directory_notation_name))
          target_group = self.group_first_or_new(new_group[:name],
            new_group[:level_no], target_all_parent_names, book)

          # 作成するグループはインポート実行時とCSV読み込み時のグループ情報が異なる(削除されたりする)場合も考慮する
          target_group.save! if target_group.new_record?
        end

        # インポートできるアドレス
        importable_addresses.each do |importable_address|
          affliated_group_names = importable_address.delete(:affliated_group_names) || {}

          # 重複した連絡先を抽出
          if book.present?
            # CSVインポートは編集権限以上のユーザーが実行できるので.addresses.extract_readable(Core.user)は不要
            # また、並び替えもインポート用のものを利用するため
            address = book.addresses.where(
              email: importable_address[:email]).order_import_update_target.first
          else
            address = Gw::WebmailAddress.where(user_id: Core.user.id,
              email: importable_address[:email]).order_import_update_target.first
          end

          # 新規連絡先
          if address.blank?
            address = self.new(importable_address)
            address.set_book_id_or_user_id_on_import_csv(book)
            address.save!
          # 重複した連絡先を更新
          else
            address.update_attributes!(importable_address)
          end

          # グループ指定が存在する場合
          if affliated_group_names.present?
            address_affiliated_group_ids = address.group_ids

            target_all_parent_names_array = affliated_group_names.values.map do |value|
              self.split_directory_notation(value.delete(:directory_notation_name))
            end

            target_all_parent_names_array.each do |target_all_parent_names|
              # 所属グループ名は最後の要素
              target_name = target_all_parent_names.last
              # 所属グループの階層レベルは要素の添字 + 1
              target_level_no = target_all_parent_names.find_index(target_name) + 1
              # 親グループ名(所属グループ名を含む)から所属グループを抽出する
              target_group = self.group_first_or_new(target_name, target_level_no, target_all_parent_names, book)
              # 作成するグループは前段で保存しているが、インポート実行時と
              # CSV読み込み時のグループ情報が異なる(削除されたりする)場合も考慮する
              target_group.save! if target_group.new_record?
              # 所属グループではない場合は所属グループ情報を登録する
              unless address_affiliated_group_ids.include?(target_group.id)
                # 共有アドレス帳の場合
                if book.present?
                  address.affiliated_groups.create!(group_id: target_group.id)
                # 個人アドレス帳の場合
                else
                  address.groupings.create!(group_id: target_group.id)
                end
              end
            end

          end

        end
      end
    end

  end

end
