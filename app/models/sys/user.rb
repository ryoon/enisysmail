# encoding: utf-8
require 'digest/sha1'
class Sys::User < Sys::ManageDatabase
  include Sys::Model::Base
  include Sys::Model::Base::Config
  include Sys::Model::Rel::RoleName
  include Sys::Model::Auth::Manager

  # 参照先テーブルをenisysmail.sys_usersからjgw_core.system_usersへ変更
  set_table_name "system_users"
  
  belongs_to :status,     :foreign_key => :state,
    :class_name => 'Sys::Base::Status'
  has_many   :group_rels, :foreign_key => :user_id,
    :class_name => 'Sys::UsersGroup'  , :primary_key => :id
  # has_and_belongs_to_many :groups,
  #   :class_name => 'Sys::Group', :join_table => 'sys_users_groups'
  # jgw_core.system_users_groupsは、主キーを持っているため、has_and_belongs_to_manyは使用しない。
  has_many :user_groups, :foreign_key => :user_id,
    :class_name => 'Sys::UsersGroup'
  has_many :groups, :through => :user_groups, :class_name => 'Sys::Group',
    :source => :group
  #has_and_belongs_to_many :role_names, :association_foreign_key => :role_id,
  #  :class_name => 'Sys::RoleName', :join_table => 'sys_users_roles'
    
  has_many :logins, :foreign_key => :user_id, :class_name => 'Sys::UserLogin',
    :order => 'id desc', :dependent => :delete_all
    
  has_many :webmail_mail_nodes, :foreign_key => :user_id, :class_name => 'Gw::WebmailMailNode',
    :order => 'id', :dependent => :destroy
  has_many :webmail_mailboxes, :foreign_key => :user_id, :class_name => 'Gw::WebmailMailbox',
    :order => 'id', :dependent => :destroy
  has_many :webmail_settings, :foreign_key => :user_id, :class_name => 'Gw::WebmailSetting',
    :order => 'id', :dependent => :destroy
  has_many :webmail_address_groups, :foreign_key => :user_id, :class_name => 'Gw::WebmailAddressGroup',
    :order => 'id', :dependent => :destroy
  has_many :webmail_addresses, :foreign_key => :user_id, :class_name => 'Gw::WebmailAddress',
    :order => 'id', :dependent => :destroy
  has_many :webmail_filters, :foreign_key => :user_id, :class_name => 'Gw::WebmailFilter',
    :order => 'id', :dependent => :destroy
  has_many :webmail_signs, :foreign_key => :user_id, :class_name => 'Gw::WebmailSign',
    :order => 'id', :dependent => :destroy
  has_many :webmail_templates, :foreign_key => :user_id, :class_name => 'Gw::WebmailTemplate',
    :order => 'id', :dependent => :destroy
  has_many :webmail_mail_address_histories, :foreign_key => :user_id, :class_name => 'Gw::WebmailMailAddressHistory',
    :order => 'id', :dependent => :destroy
  
  attr_accessor :in_group_id
  #attr_accessor :group, :group_id, :in_group_id
  
  validates_presence_of :state, :code, :name, :ldap
#  validates_length_of :mobile_password, :minimum => 4, :if => Proc.new{|u| u.mobile_password && u.mobile_password.length != 0}
  validates_uniqueness_of :code
  
  after_save :save_group, :if => %Q(@_in_group_id_changed)

  # === システム管理者か評価する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def system_admin?
    return self.has_auth?(:manager)
  end

  # === 状態が有効の所属のみを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  def enable_user_groups
    return self.user_groups.without_disable
  end

  # === enisysmail.sys_users と jgw_core.system_users のカラム名の差異の是正
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  code
  def account
    self.code
  end
  
  def readable
    self
  end
  
  def creatable?
    Core.user.has_auth?(:manager)
  end
  
  def readable?
    Core.user.has_auth?(:manager)
  end
  
  def editable?
    Core.user.has_auth?(:manager)
  end
  
  def deletable?
    Core.user.has_auth?(:manager)
  end
  
  def authes
    #[['なし',0], ['投稿者',1], ['作成者',2], ['編集者',3], ['設計者',4], ['管理者',5]]
    [['作成者',2], ['設計者',4], ['管理者',5]]
  end
  
  def auth_name
    authes.each {|a| return a[0] if a[1] == auth_no }
    return nil
  end
  
  def ldap_states
    [['同期',1],['非同期',0]]
  end
  
  def ldap_label
    ldap_states.each {|a| return a[0] if a[1] == ldap }
    return nil
  end
  
=begin
  def mobile_access_states
    [['不許可',0],['許可',1]]
  end
  
  def mobile_access_label
    mobile_access_states.each {|a| return a[0] if a[1] == mobile_access }
    return nil
  end
=end
  
  def name_with_id
    "#{name}（#{id}）"
  end

  def name_with_account
    # enisysmail.sys_users と jgw_core.system_users のカラム名の差異の是正
    "#{name}（#{code}）"
  end
  
  def label(name)
    case name; when nil; end
  end
  
  def group(load = nil)
    return @group if @group && load
    @group = groups(load).size == 0 ? nil : groups[0]
  end
  
  def group_id(load = nil)
    (g = group(load)) ? g.id : nil
  end
  
  def in_group_id
    if read_attribute(:in_group_id).nil?
      write_attribute(:in_group_id, (group ? group.id : nil))
    end
    read_attribute(:in_group_id)
  end
  
  def in_group_id=(value)
    @_in_group_id_changed = true
    write_attribute(:in_group_id, value.to_s)
  end
  
  def has_auth?(name)
    auth = {
      :none     => 0, # なし  操作不可
      :reader   => 1, # 読者  閲覧のみ
      :creator  => 2, #作成者 記事作成者
      :editor   => 3, #編集者 データ作成者
      :designer => 4, #設計者 デザイン作成者
      :manager  => 5, #管理者 設定作成者
    }
    raise "Unknown authority name: #{name}" unless auth.has_key?(name)
    # enisysmail.sys_users と jgw_core.system_users のデータ型の差異の是正(string → integer)
    return auth[name] <= auth_no.to_i
  end

  # === FIXME: システム管理者かどうかの判断フラグを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  5: システム管理者, 2: 一般ユーザー
  def auth_no
    cond = ["user_id = ?", Core.user.id]
    user_groups = Sys::UsersGroup.without_disable.where(cond)
    groups = ""
    user_groups.each do |ug|
      groups << "," unless groups.blank?
      groups << ug.group_id.to_s
    end

    if groups.present?
      childs = Sys::Group.without_disable.where("id in (#{groups})")
      childs.each do |child|
        groups << "," unless groups.blank?
        groups << child.parent_id.to_s
      end
    end

    auth_users = Sys::User.find_by_sql([<<-SQL, user_id: Core.user.id])
    SELECT * FROM system_users INNER JOIN system_roles ON system_users.id = system_roles.uid
    WHERE system_users.id = :user_id AND system_roles.priv_name = 'admin'  AND system_roles.table_name IN ('_admin', 'mail_admin')
    SQL

    auth_groups = Sys::Group.find_by_sql([<<-SQL])
    SELECT * FROM system_roles
    WHERE system_roles.uid in (#{groups}) AND system_roles.priv_name  = 'admin'  AND system_roles.table_name IN ('_admin', 'mail_admin')
    SQL

    auth = auth_users.present? || auth_groups.present?
    return auth ? 5 : 2
  end

  def has_priv?(action, options = {})
    unless options[:auth_off]
      return true if has_auth?(:manager)
    end
    return nil unless options[:item]

    item = options[:item]
    if item.kind_of?(ActiveRecord::Base)
      item = item.unid
    end
    
    cond = {:action => action.to_s, :item_unid => item}
    roles = Sys::ObjectPrivilege.find(:all, :conditions => cond)
    return false if roles.size == 0
    
    cond = Condition.new do |c|
      c.and :user_id, id
      c.and :role_id, 'ON', roles.collect{|i| i.role_id}
    end
    Sys::UsersRole.find(:first, :conditions => cond.where)
  end

  def delete_group_relations
    Sys::UsersGroup.delete_all(:user_id => id)
    return true
  end
  
  def search(params)
    
    like_param = lambda do |s|
      s.gsub(/[\\%_]/) {|r| "\\#{r}"}
    end

    params.each do |n, vs|
      next if vs.to_s == ''
      vs.split(/[ 　]+/).each do |v|
        next if v == ''
        case n
        when 's_id'
          self.and :id, v
        when 's_state'
          self.and 'system_users.state', v
        when 's_account'
          self.and 'system_users.code', 'LIKE', "%#{like_param.call(v)}%"
        when 's_name'
          self.and 'system_users.name', 'LIKE', "%#{like_param.call(v)}%"
        when 's_email'
          self.and 'system_users.email', 'LIKE', "%#{like_param.call(v)}%"
        when 's_group_id'
          if v == 'no_group'
            self.join 'LEFT OUTER JOIN system_users_groups ON system_users_groups.user_id = system_users.id' +
              ' LEFT OUTER JOIN system_groups ON system_users_groups.group_id = system_groups.id'
            self.and 'system_groups.id',  'IS', nil
          else
            self.join :groups
            self.and 'system_groups.id', v
          end
        when 's_name_or_kana'
          kana_v = v.to_s.tr("ぁ-ん", "ァ-ン")
          cond = Condition.new
          cond.or 'system_users.name', 'LIKE', "%#{like_param.call(v)}%"
          cond.or 'system_users.kana', 'LIKE', "%#{like_param.call(kana_v)}%"
          self.and cond
        end
      end
    end if params.size != 0

    return self
  end

  def self.find_managers
    cond = {:state => 'enabled', :auth_no => 5}
    self.find(:all, :conditions => cond, :order => :id)
  end
  
  ## -----------------------------------
  ## Authenticates

  ## Authenticates a user by their account name and unencrypted password.  Returns the user or nil.
  def self.authenticate(in_account, in_password, encrypted = false)
    in_password = Util::String::Crypt.decrypt(in_password) if encrypted

    user = nil
    self.new.enabled.find(:all, :conditions => {:code => in_account, :state => 'enabled'}).each do |u|
      if u.ldap == 1
        ## LDAP Auth
        if Core.ldap.connection.bound?
          Core.ldap.connection.unbind
          Core.ldap = nil
        end
        next unless Core.ldap.bind(u.ldap_distinguished_name, in_password)
        u.password = in_password
      else
        ## DB Auth
        next if in_password != u.password || u.password.to_s == ''
      end
      user = u
      break
    end
    return user
  end

  # === LDAPで使用する識別名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  識別名
  def ldap_distinguished_name
    # LDAPの識別子は所属の状態を考慮せず、
    # 本務、兼務、仮所属で並び替えた最初のグループを識別子に使用する
    ou1 = self.user_groups.order_gw_user_group_default_scope.first.group
    ous = ([ou1, ou1.parent]).compact

    return ["uid=#{self.code}", (ous.map { |ou| "ou=#{ou.ou_name}" }).join(","), "#{Core.ldap.base}"].join(",")
  end
  
  def bind_dn
    return false unless group = self.groups[0]
    
    group_path = group.parents_tree.reverse.select{|g| g.level_no > 1}
    ous = group_path.map{|g| "ou=#{g.ou_name}"}.join(',')
    
    Core.ldap.bind_dn
      .gsub("[base]", Core.ldap.base.to_s)
      .gsub("[domain]", Core.ldap.domain.to_s)
      .gsub("[uid]", self.account.to_s)
      .gsub("[ous]", ous.to_s)
  end

=begin  
  def authenticate_mobile_password(_mobile_password)
    if mobile_access == 1
      if !mobile_password.to_s.empty? && mobile_password == _mobile_password
        return self
      end
    end
    return nil
  end
=end  

  def encrypt_password
    return if password.blank?
    Util::String::Crypt.encrypt(password)
  end
  
  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  def remember_me
    self.remember_token_expires_at = 2.weeks.from_now.utc
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(:validate => false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(:validate => false)
  end

  def previous_login_date
    return @previous_login_date if @previous_login_date
    if (list = logins.find(:all, :limit => 2)).size != 2
      return nil
    end
    @previous_login_date = list[1].login_at  
  end

  def display_name
    return "#{name} (#{code})"
  end

  # === ユーザー選択UIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [value, display_name]
  def to_select_option(value_method = :id)
    return [self.name, self.send(value_method)]
  end

  # === 選択済みユーザーUIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [code, value, display_name]
  def to_json_option(value_method = :id)
    return [self.code, self.send(value_method), self.name]
  end

  # === グループIDに所属しているグループ、ユーザーIDにユーザーIDが含まれているか検証する
  #
  # ==== 引数
  #  * group_ids: グループID
  #  * user_ids: ユーザーID
  #  * skip_system_admin: システム管理者なら無条件にtrueを返す
  # ==== 戻り値
  #  boolean
  def include_member_of_group_id_or_user_id?(group_ids, user_ids, skip_system_user = true)
    # システム管理者なら無条件にtrue
    return true if skip_system_user && self.system_admin?
    # 制限なしのグループが含まれていたらtrue
    return true if group_ids.present? && group_ids.include?(Sys::Group.no_limit_group_id)
    # ユーザーIDが含まれていたらtrue
    return true if user_ids.present? && user_ids.include?(self.id)
    # 所属グループが含まれていたらtrue
    return true if group_ids.present? && group_ids != (group_ids - self.user_groups.map(&:group_id))

    return false
  end

  # === 共有アドレス帳の管理ユーザーか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def public_address_book_admin_user?
    public_address_book_role = Sys::PublicAddressBookRole.first_or_create

    return self.include_member_of_group_id_or_user_id?(
      public_address_book_role.admin_groups.map(&:group_id),
      public_address_book_role.admin_users.map(&:user_id))
  end

  # === 共有アドレス帳の編集ユーザーか判断するメソッド
  #
  # ==== 引数
  #  * public_address_book: 共有アドレス帳
  # ==== 戻り値
  #  boolean
  def public_address_book_editable_user?(public_address_book)
    # 対象の共有アドレス帳が抽出結果に存在すれば編集可能と判断する
    return Gw::WebmailPublicAddressBook.extract_editable(self).where(
      id: public_address_book.id).exists?
  end

  # === 共有アドレス帳の閲覧ユーザーか判断するメソッド
  #
  # ==== 引数
  #  * public_address_book: 共有アドレス帳
  # ==== 戻り値
  #  boolean
  def public_address_book_readable_user?(public_address_book)
    # 対象の共有アドレス帳が抽出結果に存在すれば閲覧可能と判断する
    # また、閲覧権限のみ持つ場合は状態が公開の共有アドレス帳のみ抽出する
    return Gw::WebmailPublicAddressBook.extract_readable(self).where(
      id: public_address_book.id).exists?
  end

  # === 共有アドレスの閲覧ユーザーか判断するメソッド
  #
  # ==== 引数
  #  * public_address: 共有アドレス
  # ==== 戻り値
  #  boolean
  def public_address_readable_user?(public_address)
    return Gw::WebmailPublicAddress.extract_readable(self).where(
      id: public_address.id).exists?
  end

  # === 個人設定の共有アドレス帳の並び順に使用する項目名を取得するメソッド
  #
  # ==== 引数
  #  * address_setting_key: 個人設定の個人／共有アドレス帳設定を表すSymbol
  # ==== 戻り値
  #  文字列
  def address_order_item_name(address_setting_key)
    target_user_config = Gw::WebmailSetting.where(user_id: self.id, name: address_setting_key).first
    return (target_user_config && target_user_config.value) || "email"
  end

  # === 個人設定の共有アドレス帳の並び順を取得するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def public_address_order
    return address_order_item_name(:public_address_order)
  end

  # === 個人設定の個人アドレス帳の並び順を取得するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def private_address_order
    return address_order_item_name(:address_order)
  end

protected
  def password_required?
    password.blank?
  end
  
  def save_group
    exists = (group_rels.size > 0)
    
    group_rels.each_with_index do |rel, idx|
      if idx == 0 && !in_group_id.blank?
        if rel.group_id != in_group_id
          cond = {:user_id => rel.user_id, :group_id => rel.group_id}
          rel.class.update_all({:group_id => in_group_id}, cond)
          rel.group_id = in_group_id
        end
      else
        rel.destroy
      end
    end
    
    if !exists && !in_group_id.blank?
      rel = Sys::UsersGroup.create({
        :user_id  => id,
        :group_id => in_group_id
      })
    end
    
    return true
  end

end
