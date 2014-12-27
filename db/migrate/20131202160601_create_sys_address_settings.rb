class CreateSysAddressSettings < ActiveRecord::Migration
  def self.up
    create_table :sys_address_settings, :force => true do |t|
      t.datetime :created_at
      t.datetime :updated_at
      t.string :key_name, :limit => 255
      t.integer :sort_no
      t.string :used, :limit => 1
      t.string :list_view, :limit => 1
    end
  end

  def self.down
    drop_table :sys_address_settings
  end
end
