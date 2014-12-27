class CreateGwPublicAddressBookReadableGroups < ActiveRecord::Migration
  def self.up
    create_table :gw_webmail_public_address_book_readable_groups do |t|
      t.integer :public_address_book_id

      t.integer :group_id
      t.string :group_code
      t.string :group_name

      t.timestamps
    end
  end

  def self.down
    drop_table :gw_webmail_public_address_book_readable_groups
  end
end
