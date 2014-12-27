# coding: utf-8
class Gw::Admin::Webmail::PublicAddressesController < Gw::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  layout "admin/gw/webmail"

  before_filter :set_address, only: [:show, :edit, :update, :destroy, :create_mail]
  before_filter :set_book_from_address, only: [:show, :edit, :update, :destroy, :create_mail]

  before_filter :set_book_from_params, only: [:new, :create]
  before_filter :set_sorted_address_groups, only: [:new, :create, :edit, :update]

  # 編集権限以上
  before_filter :public_address_book_editable_user!, only: [:new, :create, :edit, :update, :destroy]
  # 閲覧権限以上
  before_filter :public_address_book_readable_user!, only: [:show, :create_mail]
  # 閲覧権限のみの場合は状態が公開のアドレスのみ
  before_filter :public_address_readable_user!, only: [:show, :create_mail]

  # === 新規作成 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def new
    @address = Gw::WebmailPublicAddress.new(state: 1)

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
    @address = Gw::WebmailPublicAddress.new(params[:gw_webmail_public_address])
    @address.public_address_book_id = @book.id

    _create(@address, redirect_index_url)
  end

  # === 更新 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update
    @address.attributes = params[:gw_webmail_public_address]

    _update(@address, redirect_index_url)
  end

  # === 削除 アクション
  #  編集権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def destroy
    _destroy(@address, redirect_index_url)
  end

  # === 閲覧 アクション
  #  閲覧権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def show
  end

  # メール新規作成 アクション
  #  閲覧権限以上が必要
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def create_mail
    flash[:mail_to] = @address.display_name

    redirect_to new_gw_webmail_mail_path("INBOX")
  end

  # 以下、プライベートメソッド
  private

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

    # === 閲覧権限のみの場合は状態が公開のアドレスのみ
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def public_address_readable_user!
      http_error(404) unless Core.user.public_address_readable_user?(@address)
    end

    # === アドレスをセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def set_address
      @address = Gw::WebmailPublicAddress.where(id: params[:id]).first
      http_error(404) if @address.blank?
    end

    # === 共有アドレス帳をセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def set_book_from_params
      @book = Gw::WebmailPublicAddressBook.where(id: params[:book_id]).first
      http_error(404) if @book.blank?
    end

    # === 共有アドレス帳をアドレスから逆算しセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def set_book_from_address
      @book = @address.public_address_book
      http_error(404) if @address.blank?
    end

    # === 階層レベル > グループ名の昇順で並び替えたグループをセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  なし
    def set_sorted_address_groups
      @sorted_address_groups = Gw::WebmailPublicAddressGroup.sorted_address_groups(@book.groups)
    end

end