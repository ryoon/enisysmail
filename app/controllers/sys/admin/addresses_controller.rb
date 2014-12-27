# encoding: utf-8
class Sys::Admin::AddressesController < Sys::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  
  def pre_dispatch
    return error_auth unless Core.user.has_auth?(:manager)
  end
  
  def index
    address_settings = Sys::AddressSetting.new
    @use_readonly_keys = ["name", "email", "state"]
    @list_readonly_keys = ["name", "email"]
    @items = address_settings.find(:all, :order => "sort_no")
    @view_names = I18n.t("activerecord.attributes.gw/webmail_address").stringify_keys
  end

  def create
    # ドラッグ＆ドロップによる並び順変更(Ajax)の場合は更新を行わない。
    return unless params[:item]
    address_settings = Sys::AddressSetting.new
    begin
      before_sort_no = 0
      params[:item].each do |id, item|
        # 取得順が並び順(sort_no)
        before_sort_no += 1
        item["sort_no"] = before_sort_no
        update = address_settings.find(id)
        update.attributes = item
        update.save
      end
      flash[:notice] = 'アドレス帳のカスタマイズ情報の更新に成功しました'
    rescue
      flash[:error] = 'アドレス帳のカスタマイズ情報の更新に失敗しました'
    end
    return redirect_to(:action => :index)
  end
  
end
