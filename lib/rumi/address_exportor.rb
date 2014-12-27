# coding: utf-8
require "nkf"
require "csv"

# === アドレス帳へのエクスポート共通モジュール
#
module Rumi::AddressExportor
  # includeされた時にクラスメソッドも追加する
  extend ActiveSupport::Concern

  # === 連絡先CSVエクスポートメソッド
  #
  # ==== 引数
  #  * book: 共有アドレス帳
  # ==== 戻り値
  #  配列
  def to_csv(csv_header_keys)
    return csv_header_keys.map { |csv_header_key| self.send(csv_header_key).to_s }
  end

  # === 住所（自宅）の都道府県を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def address_state
    return split_address(self.address)[0]
  end

  # === 住所（自宅）の市区町村を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def address_city
    return split_address(self.address)[1]
  end

  # === 住所（自宅）の番地等を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def address_street
    return split_address(self.address)[2]
  end

  # === 住所（会社）の都道府県を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def company_address_state
    return split_address(self.company_address)[0]
  end

  # === 住所（会社）の市区町村を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def company_address_city
    return split_address(self.company_address)[1]
  end

  # === 住所（会社）の番地等を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def company_address_street
    return split_address(self.company_address)[2]
  end

  # === 住所を分割するメソッド
  #
  # ==== 引数
  #  * target_address: 住所
  # ==== 戻り値
  #  [都道府県, 市区町村, 番地等]
  def split_address(target_address)
    target_address = target_address.to_s
    # 最長一致で分割する
    pattern = /(.+[都|道|府|県])(.+[市|区|町|村])(.*)/

    splited_address = [target_address, "", ""]
    target_address.scan(pattern) do |state_str, city_str, street_str|
      # 都道府県、市区町村、番地等の3分割出来た場合のみ分割を許可する
      if state_str.present? && city_str.present? && street_str.present?
        splited_address = [state_str, city_str, street_str]
      end
    end

    return splited_address
  end

  # === 所属グループ名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ;区切りのグループ名
  def affliated_group_names
    target_group_names = self.groups.map { |target_group| target_group.to_directory_notation }
    return target_group_names.join(I18n.t("rumi.public_address_group.delimiter"))
  end

  # === クラスメソッド定義用モジュール
  module ClassMethods

    # === アドレス帳CSVエクスポートメソッド
    #
    # ==== 引数
    #  * csv_form: RumiHelper::CsvForm
    #  * book: 共有アドレス帳
    # ==== 戻り値
    #  CSV
    def to_csv(csv_form, book = nil)
      # 形式
      csv_format_type = csv_form.format_type
      # ヘッダ(日本語)
      csv_header_values = self.export_csv_header_values(csv_format_type)
      # ヘッダ(値取得メソッド)
      csv_header_keys = self.export_csv_header_keys(csv_format_type)

      # 共有アドレス帳の場合
      if book.present?
        # 連絡先の並び替えを行うために.addresses.extract_readable(Core.user)を実行している
        target_addresses = book.addresses.extract_readable(Core.user)
      else
        target_addresses = Gw::WebmailAddress.where(user_id: Core.user.id).order_user_setting(Core.user)
      end

      csv_string = CSV.generate(encoding: "utf-8") do |csv|
        csv << csv_header_values

        target_addresses.each do |target_address|
          csv << target_address.to_csv(csv_header_keys)
        end
      end

      # 変換後の文字列はShift_JIS、改行コードCRLFで片仮名は半角から全角へ変換しない
      csv_string = NKF.nkf("-m0 -sx -Lw", csv_string)
      return csv_string
    end

    # === CSVヘッダ(日本語)を返すメソッド
    #
    # ==== 引数
    #  * csv_format_type: 縁sys用Windows/Essentials用
    # ==== 戻り値
    #  配列
    def export_csv_header_values(csv_format_type)
      csv_header_array = []

      csv_header_key = "rumi.attributes.#{csv_format_type}.export"
      I18n.t(csv_header_key).each do |attr_key, name_or_key|
        row_name_or_hash = I18n.t([csv_header_key, attr_key].join("."))

        # 自宅/勤務先の住所
        if row_name_or_hash.is_a?(Hash)
          row_name_or_hash.each { |key, name| csv_header_array << name }
        else
          csv_header_array << row_name_or_hash
        end
      end

      return csv_header_array
    end

    # === CSVヘッダ(Key)を返すメソッド
    #
    # ==== 引数
    #  * csv_format_type: 縁sys用Windows/Essentials用
    # ==== 戻り値
    #  配列
    def export_csv_header_keys(csv_format_type)
      csv_header_array = []

      csv_header_key = "rumi.attributes.#{csv_format_type}.export"
      I18n.t(csv_header_key).each do |attr_key, name_or_key|
        row_name_or_hash = I18n.t([csv_header_key, attr_key].join("."))

        # 自宅/勤務先の住所
        if row_name_or_hash.is_a?(Hash)
          row_name_or_hash.each { |key, name| csv_header_array << key }
        else
          csv_header_array << attr_key
        end
      end

      return csv_header_array
    end

    # === エクスポートするCSVファイル名を返すメソッド
    #
    # ==== 引数
    #  * csv_form: RumiHelper::CsvForm
    #  * book: 共有アドレス帳
    # ==== 戻り値
    #  CSVファイル名(形式名_アドレス帳名_時刻.csv)
    def export_csv_filename(csv_form, book = nil)
      # 形式
      csv_format_type = csv_form.format_type
      filename = [I18n.t("activemodel.attributes.rumi_helper/csv_form.format_names.#{csv_format_type}")]

      if book.present?
        # 共有アドレス帳名
        filename << book.name
      else
        filename << I18n.t("rumi.private_address_book.name")
      end
      # 時刻
      filename << "#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv"

      # 入力文字コードはUTF-8で出力する文字コードはShift_JIS
      return NKF::nkf("-s -W", filename.join("_"))
    end

  end

end
