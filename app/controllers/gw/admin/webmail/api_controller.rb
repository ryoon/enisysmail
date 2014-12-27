# encoding: utf-8
class Gw::Admin::Webmail::ApiController < ApplicationController
  include Sys::Controller::Admin::Auth
  protect_from_forgery :except => [:unseen, :recent, :remind]
  
  def unseen
    unseen_and_recent
    
    respond_to do |format|
      format.xml { }
    end
  end
  
  def recent
    unseen_and_recent
    
    respond_to do |format|
      format.xml { }
    end
  end

  # === 未読メール情報取得API
  #  新着情報に表示する未読状態メール情報を返却する
  # ==== 引数
  #  * account: ユーザーのコード
  #  * password: ユーザーのパスワード
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  未読メール情報(JSON)
  def remind
    @remind = {}

    if params[:account] && params[:password]
      login_temporarily(params[:account], params[:password], nil) do
        # フィルタ適用
        last_uid, recent, error = Gw::WebmailFilter.apply_recents
        # 未読メール格納オブジェクト
        @mails = []
        # 全メールボックスを取得
        Gw::WebmailMailbox.load_mailboxes(:all).each do |box|
          # 送信済みトレイ、下書き、ゴミ箱、スター付き、アーカイブメールボックスは未読メールの検索対象外とする
          next if box.name =~ /^(Sent|Drafts|Trash|Star)(\.|$)/
          @mails << Gw::WebmailMail.find(:all, :select => box.name, :conditions => "UNSEEN")
        end

        @mails.flatten!
        if @mails.present?
          @remind[:total_count] = @mails.size
          @mails.sort_by! { |mail| mail.date } if params[:sort_key] == "datetime"
          @mails.sort_by! { |mail| mail.subject } if params[:sort_key] == "title"
          @mails.reverse! if params[:order] == "desc"

          factors = @mails.slice(0, 20).map do |mail|
            path = "/_admin/gw/webmail/#{mail.mailbox}/mails?opt_id=#{mail.uid}"
            {
              :datetime => mail.date,
              :title => mail.subject,
              :url => "/_admin/gw/link_sso/64/redirect_rumi_mail?path=#{CGI::escape(path)}",
              :action => :receive
            }
          end

          @remind[:factors] = factors
        end

      end
    end

    render :json => @remind, :layout => false
  end

  # === グループリスト更新用xhrアクション
  def get_child_groups
    group_id = params[:s_genre].to_s

    without_disable = params[:without_disable].to_s == "true"
    groups = Sys::Group.child_groups_to_select_option(group_id, {
      without_disable: without_disable, unshift_parent_group: true})

    @groups = groups.map { |group| group.to_json_option }

    respond_to do |format|
      format.json { render json: @groups, layout: false }
    end
  end

  # === ユーザリスト更新用xhrアクション
  def get_users
    group_id = params[:s_genre].to_s
    users = Sys::UsersGroup.affiliated_users_to_select_option(group_id, {
      without_level_no_2_organization: params[:without_level_no_2_organization].to_s == "true"})

    @users = users.map { |user| user.to_json_option }

    respond_to do |format|
      format.json { render json: @users, layout: false }
    end
  end

protected
  
  def login_temporarily(account, password, mobile_password)
    if request.mobile?
      login_ok = new_login_mobile(account, password, mobile_password)
    else
      login_ok = new_login(account, password)
    end
    if login_ok
      Core.user          = current_user
      Core.user.password = Util::String::Crypt.decrypt(session[PASSWD_KEY])
      Core.user_group    = current_user.groups[0]
      Core.current_user  = Core.user
      yield
      reset_session
    end
  end
  
  def unseen_and_recent
    @unseen = -1
    @recent = -1
    @mailboxes = []
    
    if params[:account] && params[:password]
      @account = params[:account]
      login_temporarily(params[:account], params[:password], params[:mobile_password]) do
        @unseen = 0
        @recent = 0
        @mailboxes = Gw::WebmailMailbox.load_mailboxes(:all)
        @mailboxes.each do |box|
          next if box.name =~ /^(Sent|Drafts|Trash|Star)(\.|$)/
          @unseen += box.unseen
          @recent += box.recent
        end
      end
    end
  end
end
