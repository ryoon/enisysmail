# coding: utf-8
class Gw::Admin::Webmail::PublicAddressBooksController < Gw::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  layout "admin/gw/webmail"

  before_filter :set_book, only: [
    :edit, :update, :destroy,
    :import, :candidate_import, :exec_import,
    :export, :exec_export
  ]

  # 管理権限以上
  before_filter :public_address_book_admin_user!, only: [:new, :create, :destroy]
  # 編集権限以上
  before_filter :public_address_book_editable_user!, only: [
    :edit, :update,
    :import, :candidate_import, :exec_import,
    :export, :exec_export
  ]

  # === 一覧 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def index
    # 閲覧可能な共有アドレス帳のみ一覧表示する
    @books = Gw::WebmailPublicAddressBook.extract_readable(Core.user)

    _index(@books)
  end

  # === 新規作成 アクション
  #  管理権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def new
    @book = Gw::WebmailPublicAddressBook.new(
      state: Gw::WebmailPublicAddressBook.opened_state_value)

    respond_to do |format|
      format.html
    end
  end

  # === 登録 アクション
  #  管理権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def create
    @book = Gw::WebmailPublicAddressBook.new(params[:gw_webmail_public_address_book])

    _create(@book)
  end

  # === 更新 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update
    @book.attributes = params[:gw_webmail_public_address_book]

    _update(@book)
  end

  # === 編集 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def edit
  end

  # === 削除 アクション
  #  管理権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def destroy
    _destroy(@book)
  end

  # === メール、テンプレート画面にて全共有アドレス帳に対する検索 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def search_address
    # 閲覧可能なアドレスのみ抽出する
    @addresses = Gw::WebmailPublicAddress.extract_readable(Core.user)

    @addresses = @addresses.search_emails(params[:email])
    @addresses = @addresses.search_name_or_kanas(params[:name])

    respond_to do |format|
      format.xml
    end
  end

  # === CSVインポート画面 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def import
    @csv_form = RumiHelper::CsvForm.new_import_mode
  end

  # === CSVインポート確認画面 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def candidate_import
    @csv_form = RumiHelper::CsvForm.new(params[:rumi_helper_csv_form] || {})

    begin
      raise @csv_form.error_full_messages if @csv_form.invalid?

      values = Gw::WebmailPublicAddress.candidate_import_csv(@csv_form, @book)

      @valid_addresses = values[:valid_addresses]
      @invalid_addresses = values[:invalid_addresses]
      @new_groups = values[:new_groups]

      respond_to do |format|
        format.html { render action: :candidate_import, id: @book.id }
      end

    rescue => e
      flash.now[:notice] = I18n.t("rumi.public_address_book.action.csv.import.message.error")

      # 本番のログでも出力する
      Rails.logger.error "[ERROR] public address candidate_import_csv Invalid Error"
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)

      respond_to do |format|
        format.html { render action: :import, id: @book.id }
      end
    end
  end

  # === CSVインポート実行 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def exec_import
    candidate_data = params[:candidate_data] || {}
    # CSV形式を特定するためインスタンスを生成
    csv_form = RumiHelper::CsvForm.new(format_type: params[:csv_format_type])

    begin
      Gw::WebmailPublicAddress.import_csv(candidate_data, csv_form, @book)

      flash[:notice] = I18n.t("rumi.public_address_book.action.csv.import.message.success")
    rescue => e
      # 本番のログでも出力する
      Rails.logger.error "[ERROR] public address exec_import_csv Invalid Error"
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)

      flash[:notice] = I18n.t("rumi.public_address_book.action.csv.import.message.error")
    ensure
      respond_to do |format|
        format.html { redirect_to action: :import, id: @book.id }
      end
    end

  end

  # === CSVエクスポート画面 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def export
    @csv_form = RumiHelper::CsvForm.new_export_mode
  end

  # === CSVエクスポート実行 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def exec_export
    @csv_form = RumiHelper::CsvForm.new(params[:rumi_helper_csv_form] || {})

    begin
      raise @csv_form.error_full_messages if @csv_form.invalid?

      csv_string = Gw::WebmailPublicAddress.to_csv(@csv_form, @book)
      filename = Gw::WebmailPublicAddress.export_csv_filename(@csv_form, @book)

      send_data csv_string, filename: filename, type: "text/csv", disposition: "attachment"

    rescue => e
      flash.now[:notice] = I18n.t("rumi.public_address_book.action.csv.export.message.error")

      # 本番のログでも出力する
      Rails.logger.error "[ERROR] public address exec_export_csv Invalid Error"
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)

      respond_to do |format|
        format.html { render action: :export, id: @book.id }
      end
    end
  end

  # 以下、プライベートメソッド
  private

    # === 管理権限を持つユーザーか評価するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def public_address_book_admin_user!
      http_error(404) unless Core.user.public_address_book_admin_user?
    end

    # === 編集権限を持つユーザーか評価するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def public_address_book_editable_user!
      http_error(404) unless Core.user.public_address_book_editable_user?(@book)
    end

    # === 共有アドレス帳をセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def set_book
      @book = Gw::WebmailPublicAddressBook.where(id: params[:id]).first
      http_error(404) if @book.blank?
    end
end
