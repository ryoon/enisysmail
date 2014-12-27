class CreateGwPublicAddressBookReadableUsers < ActiveRecord::Migration
  def self.up
    create_table :gw_webmail_public_address_book_readable_users do |t|
      t.integer :public_address_book_id

      t.integer :user_id
      t.string :user_code
      t.string :user_name

      t.timestamps
    end
  end

  def self.down
    drop_table :gw_webmail_public_address_book_readable_users
  end
end
