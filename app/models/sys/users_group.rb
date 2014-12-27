class Sys::UsersGroup < Sys::ManageDatabase
  include Sys::Model::Base
  include Sys::Model::Base::Config
  include Sys::Model::Auth::Manager
  
  # 参照先テーブルをenisysmail.sys_users_groupsからjgw_core.system_users_groupsへ変更
  set_table_name "system_users_groups"
  
  set_primary_key :rid
  
  belongs_to   :user,  :foreign_key => :user_id,  :class_name => 'Sys::User'
  belongs_to   :group, :foreign_key => :group_id, :class_name => 'Sys::Group'

  # Sys::Group.affiliated_users_to_select_optionで使用するoptions
  TO_SELECT_OPTION_SETTINGS = {
    default: {
      without_level_no_2_organization: true
    },
    system_role: {
      without_level_no_2_organization: false
    }
  }

  # === Gwにおけるユーザーグループのデフォルトスコープ
  #  本務・兼務(0: 本務、1:兼務、2: 仮所属、3: null)
  scope :order_gw_user_group_default_scope, lambda {
    order("system_users_groups.job_order is null", "system_users_groups.job_order")
  }

  # === ユーザーのデフォルトスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :order_user_default_scope, lambda {
    includes(:user).order("system_users.sort_no", "system_users.code", "system_users.id")
  }

  # === 有効な所属情報のみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable, lambda {
    current_time = Time.now
    where("system_users_groups.end_at is null or system_users_groups.end_at = '0000-00-00 00:00:00' or system_users_groups.end_at > '#{current_time.strftime("%Y-%m-%d 23:59:59")}'")
  }

  # === 階層レベル2でかつ、組織グループを抽出から外すスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_level_no_2_organization, lambda {
    includes(:group).where("(system_groups.level_no = 3 and system_groups.category = 0) or (system_groups.level_no > 1 and system_groups.category = 1)")
  }

  # === 所属選択UIにて表示するユーザーの抽出を行うメソッド
  #
  # ==== 引数
  #  * target_group_id: 抽出対象のグループID
  #  * options: Hash
  #      e.g. without_level_no_2_organization: boolean
  # ==== 戻り値
  #  Array.<user>
  def self.affiliated_users_to_select_option(target_group_id, options = Sys::UsersGroup::TO_SELECT_OPTION_SETTINGS[:default])
    to_without_level_no_2_organization = options.key?(:without_level_no_2_organization) && options[:without_level_no_2_organization] == true

    user_groups = Sys::UsersGroup.unscoped.where(group_id: target_group_id)
    user_groups = user_groups.without_level_no_2_organization if to_without_level_no_2_organization
    user_groups = user_groups.without_disable.order_user_default_scope

    return user_groups.map { |user_group| user_group.user }
  end

  # === 任意グループを抽出から外すスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_option_groups, lambda {
    includes(:group).where("system_groups.category = 0")
  }
end
