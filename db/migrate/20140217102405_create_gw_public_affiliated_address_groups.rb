class CreateGwPublicAffiliatedAddressGroups < ActiveRecord::Migration
  def self.up
    create_table :gw_webmail_public_affiliated_address_groups do |t|
      t.integer :public_address_book_id

      t.integer :group_id
      t.integer :address_id

      t.timestamps
    end
  end

  def self.down
    drop_table :gw_webmail_public_affiliated_address_groups
  end
end
