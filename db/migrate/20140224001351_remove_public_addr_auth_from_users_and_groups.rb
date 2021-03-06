class RemovePublicAddrAuthFromUsersAndGroups < ActiveRecord::Migration
  def self.up
    remove_column :sys_users, :public_addr_auth
    remove_column :sys_groups, :public_addr_auth
  end

  def self.down
    add_column :sys_users, :public_addr_auth, :boolean, default: false
    add_column :sys_groups, :public_addr_auth, :boolean, default: false
  end
end
