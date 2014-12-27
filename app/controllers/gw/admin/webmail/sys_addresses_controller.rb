# encoding: utf-8
class Gw::Admin::Webmail::SysAddressesController < Gw::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  include Gw::Controller::Admin::Mobile::Address
  helper Gw::MailHelper
  layout "admin/gw/webmail"
  
  def pre_dispatch
    return redirect_to :action => :index if params[:reset]
    # アドレス帳検索 検索結果最大表示件数を取得
    @search_limit = Enisys.config.application['webmail.search_address_max_count'].to_i
    @order = Gw::WebmailSetting.user_config_value(:sys_address_order)
  end
  
  def index
    @root = Sys::Group.find_by_id(1)
    return http_error(404) unless @root
    
    @parents = []
    @group   = @root
    @groups  = @group.enabled_children.soshiki_groups
    @my_groups = Core.user.user_groups.includes(:group).order("system_users_groups.job_order", "system_groups.sort_no").without_disable.without_option_groups
   
    if params[:search]
      user = Sys::User.new
      user.and "system_users.state", "enabled"
      user.and "system_users.ldap", 1 if Sys::Group.show_only_ldap_user
      user.and "system_users.email", 'IS NOT', nil
      user.and "system_users.email", "!=", ""
      user.page 1, @search_limit
      user.search params
      @users = user.find(:all, :include => :groups, :order => get_orders.map{|x|"system_users.#{x}"}.join(', '))
    #else
    #  @users = @group.ldap_users.find(:all, :conditions => ["email IS NOT NULL AND email != ''"])
    end

    respond_to do |format|
      format.html {}
      format.xml {}
      format.js   {}
    end
  end
  
  def show
    user = Sys::User.new.enabled
    user.and :id, params[:id]
    user.and :ldap, 1 if Sys::Group.show_only_ldap_user
    @item = user.find(:first)
    return http_error(404) unless @item && !@item.email.blank?

    if params[:group_id] =~ /\ASearch/
      # アドレス帳検索結果画面からの閲覧画面表示
      @group_item = @item.group
    else
      # 所属別アドレス帳画面からの閲覧画面表示
      group = Sys::Group.new.enabled
      group.and :id, params[:group_id]
      @group_item = group.find(:first)
    end
    return http_error(404) unless @group_item

    respond_to do |format|
      format.html { render :layout => false }
    end
  end
  
  ## post/create mail
  def create
    to = ids_to_addrs(params[:to])
    cc = ids_to_addrs(params[:cc])
    bcc = ids_to_addrs(params[:bcc])
    flash[:mail_to]  = to.join(', ')  if to.size  > 0
    flash[:mail_cc]  = cc.join(', ')  if cc.size  > 0
    flash[:mail_bcc] = bcc.join(', ') if bcc.size > 0
    redirect_to new_gw_webmail_mail_path('INBOX')
  end

  def create_mail
    to = ids_to_addrs(params[:id])
    flash[:mail_to] = to.join(', ')  if to.size  > 0
    redirect_to new_gw_webmail_mail_path('INBOX')
  end
  
  def child_groups
    @group = Sys::Group.find_by_id(params[:id])
    return http_error(404) unless @group

    @groups  = @group.enabled_children

    respond_to do |format|
      format.xml
    end
  end

  def child_users
    @group = Sys::Group.find_by_id(params[:id])
    return http_error(404) unless @group
    @users = @group.users_having_email(get_order)
    respond_to do |format|
      format.xml  { }
    end
  end

  def child_items
    @group = Sys::Group.find_by_id(params[:id])
    return http_error(404) unless @group    
    @groups = @group.enabled_children
    @users  = @group.users_having_email(get_order)
    respond_to do |format|
      format.xml  { }
    end
  end

  # === アドレス登録先アドレス帳選択UI表示 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def address_book_selector
    respond_to do |format|
      format.html { render :address_book_selector, layout: false }
    end
  end

protected
  def search_children(group)
    searched = {}
    list = []
    cond = {:parent_id => group.id, :state => 'enabled'}
    Sys::Group.find(:all, :conditions => cond, :order => "sort_no, code").each do |g|
      next if searched.key?(g.id)
      searched[g.id] = 1
      list << g
      list += search_children(g)
    end
    list
  end
  
  def ids_to_addrs(ids)
    if ids.is_a?(Hash)
      ids = ids.keys.uniq
    elsif ids.is_a?(String) && !ids.blank?
      ids = [ids]
    else
      return []
    end
    item = Sys::User.new
    item.and :id, 'IN', ids
    item.and "system_users.state", "enabled"
    item.and "system_users.ldap", 1 if Sys::Group.show_only_ldap_user
    item.and :email, 'IS NOT', nil
    item.and :email, '!=', ''
    item.find(:all, :order => "email").collect {|u| %Q(#{u.name} <#{u.email}>) }
  end
  
  def get_orders
    orders = []
    orders << (@order.blank? ? 'email' : @order)
    orders << 'code'
  end
  
  def get_order
    get_orders.join(', ')
  end
end
