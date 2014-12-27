class CreateSysPublicAddressBookAdminUsers < ActiveRecord::Migration
  def self.up
    create_table :sys_public_address_book_admin_users do |t|
      t.integer :public_address_book_role_id

      t.integer :user_id
      t.string :user_code
      t.string :user_name

      t.timestamps
    end
  end

  def self.down
    drop_table :sys_public_address_book_admin_users
  end
end
