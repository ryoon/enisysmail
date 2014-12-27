class CreateSysPublicAddressBookAdminRoles < ActiveRecord::Migration
  def self.up
    create_table :sys_public_address_book_roles do |t|
      t.text :admin_groups_json
      t.text :admin_users_json

      t.timestamps
    end
  end

  def self.down
    drop_table :sys_public_address_book_roles
  end
end
