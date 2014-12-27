# encoding: utf-8
class Sys::Group < Sys::ManageDatabase
  include Sys::Model::Base
  include Sys::Model::Base::Config
  include Sys::Model::Tree
  include Sys::Model::Auth::Manager
  
  # 参照先テーブルをenisysmail.sys_groupsからjgw_core.system_groupsへ変更
  set_table_name "system_groups"

  # Sys::Group.child_groups_to_select_optionで使用するoptions
  TO_SELECT_OPTION_SETTINGS = {
    default: {
      without_disable: true,
      unshift_parent_group: true
    }
  }
  
  belongs_to :status    , :foreign_key => :state    , :class_name => 'Sys::Base::Status'
  belongs_to :web_status, :foreign_key => :web_state, :class_name => 'Sys::Base::Status'
  belongs_to :parent    , :foreign_key => :parent_id, :class_name => 'Sys::Group'
###  belongs_to :layout    , :foreign_key => :layout_id, :class_name => 'Cms::Layout'
  
  has_many :children  , :foreign_key => :parent_id, :class_name => 'Sys::Group',
    :order => :sort_no, :dependent => :destroy
  has_many :enabled_children  , :foreign_key => :parent_id, :class_name => 'Sys::Group',
    :conditions => {:state => 'enabled'},
    :order => :sort_no, :dependent => :destroy
  
  # has_and_belongs_to_many :users, :class_name => 'Sys::User',
  #   :join_table => 'sys_users_groups', :order => 'sys_users.email, sys_users.account'
  # has_and_belongs_to_many :ldap_users, :class_name => 'Sys::User',
  #   :conditions => {:ldap => 1, :state => 'enabled'},
  #   :join_table => 'sys_users_groups', :order => 'sys_users.email, sys_users.account'
  # has_and_belongs_to_many :enabled_users, :class_name => 'Sys::User',
  #   :conditions => {:state => 'enabled'},
  #   :join_table => 'sys_users_groups', :order => 'sys_users.email, sys_users.account'
  # jgw_core.system_users_groupsは、主キーを持っているため、has_and_belongs_to_manyは使用しない。
  has_many :user_groups, :foreign_key => :group_id,
    :class_name => 'Sys::UsersGroup'
  has_many :enabled_users, :through => :user_groups, :class_name => 'Sys::User',
    :conditions => {:state => 'enabled'}, :foreign_key => :id,
    :source => :user, :order => 'system_users.email, system_users.code'
  
  validates_presence_of :state, :level_no, :code, :name, :name_en, :ldap
  validates_uniqueness_of :code
  
  before_destroy :disable_users
  
  def ldap_users_having_email(order = "id")
    self.ldap_users.find(:all, :conditions => ["email IS NOT NULL AND email != ''"], :order => order)
  end

  def count_ldap_users_having_email
    self.ldap_users.count(:all, :conditions => ["email IS NOT NULL AND email != ''"])
  end
  
  def enabled_users_having_email(order = "id")
    self.enabled_users.find(:all, :conditions => ["email IS NOT NULL AND email != ''"], :order => order)
  end
  
  def count_enabled_users_having_email
    self.enabled_users.count(:all, :conditions => ["email IS NOT NULL AND email != ''"])
  end
  
  def self.show_only_ldap_user
    Enisys.config.application['webmail.show_only_ldap_user'] == 1
  end
  
  def users_having_email(order = "id")
    if Sys::Group.show_only_ldap_user
      ldap_users_having_email(order)
    else
      enabled_users_having_email(order)
    end
  end
  
  def count_users_having_email
    if Sys::Group.show_only_ldap_user
      count_ldap_users_having_email
    else
      count_enabled_users_having_email
    end
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
  
  def ldap_states
    [['同期',1],['非同期',0]]
  end
  
  def web_states
    [['公開','public'],['非公開','closed']]
  end
  
  def ldap_label
    ldap_states.each {|a| return a[0] if a[1] == ldap }
    return nil
  end
  
  def ou_name
    "#{code}#{name}"
  end
  
  def full_name
    n = name
    n = "#{parent.name}　#{n}" if parent && parent.level_no > 1
    n
  end
  
  def candidate(include_top = false)
    choices = []
    
    down = lambda do |p, i|
      if new_record? || p.id != id
        choices << [('　　' * i) + p.name, p.id]
        p.children.each {|child| down.call(child, i + 1)}
      end
    end

    group = self.class.new
    group.and 'level_no', 1
    top = group.find(:first)
    if include_top
      roots = [top]
    else
      roots = top.children 
    end
    roots.each {|i| down.call(i, 0)}
    
    choices
  end
  
  # === 並び替えのスコープ
  #  グループの表示順 > グループコード昇順
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :order_sort_no_and_code, lambda {
    order("system_groups.sort_no", "system_groups.code", "system_groups.id")
  }

  # === 有効なグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable, where(state: "enabled")

  # === 階層レベル2, 3のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_root, where("level_no > 1")

  # === 階層レベル1のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_root, where(level_no: 1)

  # === 階層レベル2のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_level_no_2, where(level_no: 2)

  # === 階層レベル3のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_level_no_3, where(level_no: 3)

  # === 指定ID及びその子グループを抽出するスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :child_groups, ->(gid) {
    at = arel_table
    where(state: 'enabled').where(at[:id].eq(gid).or(at[:parent_id].eq(gid)))
  }

  # === 組織グループのみを抽出するスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :soshiki_groups, where(category: 0)

  # === 所属選択UIにて階層レベルを表す表現の選択肢用の表示名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列 Format: "+-- (code) name"
  def display_name_with_level_no
    return ["+", "--" * (self.level_no.to_i - 1), " ", self.name].join
  end

  # === 所属選択UIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [value, display_name_with_level_no]
  def to_select_option(value_method = :id)
    return [self.display_name_with_level_no, self.send(value_method)]
  end

  # === 選択済み所属UIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [code, value, display_name_with_level_no]
  def to_json_option(value_method = :id)
    return [self.code, self.send(value_method), self.display_name_with_level_no]
  end

  # === 所属選択UIにて表示するグループの抽出を行うメソッド
  #
  # ==== 引数
  #  * target_group_id: 抽出対象のグループID
  #  * options: Hash
  #      e.g. without_disable: boolean, unshift_parent_group: boolean
  # ==== 戻り値
  #  Array.<group>
  def self.child_groups_to_select_option(target_group_id, options = Sys::Group::TO_SELECT_OPTION_SETTINGS[:default])
    to_without_disable = options.key?(:without_disable) && options[:without_disable] == true
    to_unshift_parent_group = options.key?(:unshift_parent_group) && options[:unshift_parent_group] == true

    # 制限なしの場合
    if Sys::Group.no_limit_group_id?(target_group_id)
      groups = []
      groups << Sys::Group.no_limit_group if to_unshift_parent_group

      return groups
    else
      # 階層レベル1のグループの場合
      return [] if Sys::Group.root_id?(target_group_id)

      # それ以外の場合
      groups = Sys::Group.where(parent_id: target_group_id)
      groups = groups.without_disable if to_without_disable
      groups = groups.order_sort_no_and_code
      unshift_parent_group = Sys::Group.where(id: target_group_id).first if to_unshift_parent_group
    end

    groups = groups.to_a.unshift(unshift_parent_group) if to_unshift_parent_group

    return groups
  end

  # === 所属選択UIにて制限なしを表す選択肢を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Sys::Group
  def self.no_limit_group
    item = Sys::Group.new(level_no: 1, code: 0,
      name: I18n.t("rumi.sys/group.no_limit.name"))
    item.id = Sys::Group.no_limit_group_id

    return item
  end

  # === 所属選択UIにて制限なしを表すGroupのIDを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  0
  def self.no_limit_group_id
    return 0
  end

  # === 制限なしを表すGroupのIDか評価するメソッド
  #
  # ==== 引数
  #  * target_group_id: ID
  # ==== 戻り値
  #  boolean
  def self.no_limit_group_id?(target_group_id)
    return Sys::Group.no_limit_group_id.to_s == target_group_id.to_s
  end

  # === 階層レベル1のグループのレコードIDを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  レコードID
  def self.root_id
    return Sys::Group.extract_root.first.id
  end

  # === 階層レベル1のグループのIDか評価するメソッド
  #
  # ==== 引数
  #  * target_group_id: ID
  # ==== 戻り値
  #  boolean
  def self.root_id?(target_group_id)
    return Sys::Group.root_id.to_s == target_group_id.to_s
  end

private
  def disable_users
    users.each do |user|
      if user.groups.size == 1
        u = Sys::User.find_by_id(user.id)
        u.state = 'disabled'
        u.save
      end
    end
    return true
  end
end
