# coding: utf-8
# === 共有アドレス帳管理権限機能コントローラ
class Sys::Admin::PublicAddressBookRolesController < Sys::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base

  before_filter :set_role, only: [:edit, :update]

  def pre_dispatch
    return error_auth unless Core.user.has_auth?(:manager)
    return redirect_to(request.env['PATH_INFO']) if params[:reset]
  end

  # === 共有アドレス帳管理権限一覧アクション
  def index
    # find_or_create
    @role = Sys::PublicAddressBookRole.first_or_create
  end

  # === 共有アドレス帳管理権限編集アクション
  def edit
  end

  # === 共有アドレス帳管理権限更新アクション
  def update
    @role.attributes = params[:sys_public_address_book_role]

    _update(@role)
  end

  # 以下、プライベートメソッド
  private

    # === 共有アドレス帳管理権限をセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  http_error(404)
    def set_role
      @role = Sys::PublicAddressBookRole.first_or_create

      http_error(404) if @role.blank?
    end
end
