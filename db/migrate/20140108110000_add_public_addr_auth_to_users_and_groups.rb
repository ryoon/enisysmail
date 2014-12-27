class AddPublicAddrAuthToUsersAndGroups < ActiveRecord::Migration
  def self.up
    add_column :sys_users, :public_addr_auth, :boolean, default: false
    add_column :sys_groups, :public_addr_auth, :boolean, default: false
  end

  def self.down
    remove_column :sys_users, :public_addr_auth
    remove_column :sys_groups, :public_addr_auth
  end
end
