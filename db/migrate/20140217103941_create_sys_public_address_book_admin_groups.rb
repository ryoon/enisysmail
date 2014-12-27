class CreateSysPublicAddressBookAdminGroups < ActiveRecord::Migration
  def self.up
    create_table :sys_public_address_book_admin_groups do |t|
      t.integer :public_address_book_role_id

      t.integer :group_id
      t.string :group_code
      t.string :group_name

      t.timestamps
    end
  end

  def self.down
    drop_table :sys_public_address_book_admin_groups
  end
end
