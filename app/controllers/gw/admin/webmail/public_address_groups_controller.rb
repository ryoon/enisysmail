# coding: utf-8
class Gw::Admin::Webmail::PublicAddressGroupsController < Gw::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  layout "admin/gw/webmail"

  before_filter :set_book, only: [:index, :new, :create, :update_affiliated_address, :child_items]
  before_filter :set_group_and_book, only: [:edit, :update, :destroy]

  # 編集権限以上
  before_filter :public_address_book_editable_user!, only: [:new, :create, :edit, :update, :destroy]
  # 閲覧権限以上
  before_filter :public_address_book_readable_user!, only: [:index, :update_affiliated_address, :child_items]

  # === 一覧、検索 アクション
  #  閲覧権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def index
    @root_groups = @book.root_groups
    # 閲覧可能なアドレスのみ抽出する
    @addresses = @book.addresses.extract_readable(Core.user)

    # 検索
    if params[:search].present?
      @addresses = @addresses.search_emails(params[:s_email])
      @addresses = @addresses.search_name_or_kanas(params[:s_name_or_kana])
    end

    # リセット
    if params[:reset].present?
      params.delete(:s_email)
      params.delete(:s_name_or_kana)
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  # === 新規作成 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def new
    @group = Gw::WebmailPublicAddressGroup.new

    respond_to do |format|
      format.html
    end
  end

  # === 登録 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def create
    @group = Gw::WebmailPublicAddressGroup.new(params[:gw_webmail_public_address_group])
    @group.public_address_book_id = @book.id
    @group.set_level_no_from_parent

    _create(@group, redirect_index_url)
  end

  # === 編集 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def edit
  end

  # === 更新 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update
    @group.attributes = params[:gw_webmail_public_address_group]
    @group.set_level_no_from_parent

    _update(@group, redirect_index_url)
  end

  # === 削除 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def destroy
    _destroy(@group, redirect_index_url)
  end

  # === 共有アドレス帳にてグループ選択時のアドレス更新 アクション
  #  閲覧権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  http_error(404)
  def update_affiliated_address
    # すべて
    if Sys::Group.no_limit_group_id?(params[:id])
      group_name = I18n.t("rumi.public_address_group.all_address_group.name")

      # 閲覧可能なアドレスのみ抽出する
      addresses = @book.addresses.extract_readable(Core.user)
    else
      # 検索結果
      if params[:id].to_s == "search"
        group_name = I18n.t("rumi.public_address_group.search_group.name")

        # 閲覧可能なアドレスのみ抽出する
        addresses = @book.addresses.extract_readable(Core.user)
        addresses = addresses.search_emails(params[:s_email])
        addresses = addresses.search_name_or_kanas(params[:s_name_or_kana])
      # グループ指定
      else
        @group = @book.groups.where(id: params[:id]).first
        http_error(404) if @group.blank?
        group_name = @group.name

        # 閲覧可能なアドレスのみ抽出する
        addresses = @group.addresses.extract_readable(Core.user)
      end
    end

    render "shared/address_groups/_address", layout: false, locals: { addresses: addresses, group_name: group_name }
  end

  # メール新規作成 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def create_mail
    to = ids_to_addresses(params[:to])
    cc = ids_to_addresses(params[:cc])
    bcc = ids_to_addresses(params[:bcc])

    address_delimiter = ", "
    flash[:mail_to] = to.join(address_delimiter) if to.size > 0
    flash[:mail_cc] = cc.join(address_delimiter) if cc.size > 0
    flash[:mail_bcc] = bcc.join(address_delimiter) if bcc.size > 0

    redirect_to new_gw_webmail_mail_path("INBOX")
  end

  # メール、テンプレート画面にて共有アドレス帳のグループ選択 アクション
  #  閲覧権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  http_error(404)
  def child_items
    group = @book.groups.where(id: params[:id]).first
    http_error(404) if group.blank?
    @groups = group.children

    # 閲覧可能なアドレスのみ抽出する
    @addresses = group.addresses.extract_readable(Core.user)

    respond_to do |format|
      format.xml
    end
  end

  # 以下、プライベートメソッド
  private

    # メール新規作成補助メソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  なし
    def ids_to_addresses(ids)
      return [] if ids.blank? || !ids.is_a?(Hash)
      # 閲覧可能なアドレスのみ抽出する
      to_addresses = Gw::WebmailPublicAddress.where(id: ids.keys).without_email_blank.extract_readable(Core.user)

      return to_addresses.collect { |address| address.display_name }
    end

    # 所属する共有アドレス帳へリダイレクトURLを生成するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  なし
    def redirect_index_url
      return { location: gw_webmail_public_address_groups_path(book_id: @book.id) }
    end

    # === 編集権限以上の権限を持つユーザーか評価するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def public_address_book_editable_user!
      http_error(404) unless Core.user.public_address_book_editable_user?(@book)
    end

    # === 閲覧権限以上の権限を持つユーザーか評価するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def public_address_book_readable_user!
      http_error(404) unless Core.user.public_address_book_readable_user?(@book)
    end

    # === 共有アドレス帳をセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def set_book
      @book = Gw::WebmailPublicAddressBook.where(id: params[:book_id]).first
      http_error(404) if @book.blank?
    end

    # === グループをセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def set_group_and_book
      @group = Gw::WebmailPublicAddressGroup.where(id: params[:id]).first
      http_error(404) if @group.blank?

      @book = @group.public_address_book
      http_error(404) if @book.blank?
    end

end