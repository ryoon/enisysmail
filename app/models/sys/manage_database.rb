# encoding: utf-8
class Sys::ManageDatabase < ActiveRecord::Base
  self.abstract_class = true
  # 参照先データベースをenisysmailからjgw_coreに設定
  # 詳細は config/database.ymlに設定
  establish_connection :jgw_core rescue nil
end
