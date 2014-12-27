# encoding: utf-8
class Gw::WebmailAddress < ActiveRecord::Base
  include Sys::Model::Base
  include Sys::Model::Auth::Free

  include Rumi::AddressImportor
  include Rumi::AddressExportor

  has_many :groupings, :foreign_key => :address_id, :class_name => 'Gw::WebmailAddressGrouping',
    :dependent => :destroy
  has_many :groups, :through => :groupings, :order => 'name, id'
  #belongs_to :group, :foreign_key => :group_id, :class_name => 'Gw::WebmailAddressGroup'
  
  attr_accessor :easy_entry, :escaped, :in_groups, :settings, :copy_public_address_id
  
  before_validation :copy_public_address_info_on_easy_entry
  validates :user_id, :name, :email, presence: true
  validate :validate_attributes
  validate :email_valid_on_update

  after_save :save_groups
  
  #CONSTANTS
  NO_GROUP = 'no_group'

  # === 個人アドレス帳個人設定の並び順
  #
  # ==== 引数
  #  * target_user
  # ==== 戻り値
  #  並び替え後の結果(ActiveRecord::Relation)
  scope :order_user_setting, lambda { |target_user|
    # address_order #=> email, kana, sort_no
    order("gw_webmail_addresses.#{target_user.private_address_order}", "gw_webmail_addresses.id")
  }

  # === CSVインポート時に更新対象の連絡先用の並び順
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  並び替え後の結果(ActiveRecord::Relation)
  scope :order_import_update_target, order("gw_webmail_addresses.id")

  # === Ajaxからの登録処理において共有アドレス帳からの場合は共有アドレスの情報をコピーするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def copy_public_address_info_on_easy_entry
    if self.easy_entry
      copy_public_address = Gw::WebmailPublicAddress.extract_readable(
        Core.user).where(id: self.copy_public_address_id).first

      if copy_public_address.present?
        self.sort_no = copy_public_address.sort_no
        self.uri = copy_public_address.uri
        self.tel = copy_public_address.tel
        self.fax = copy_public_address.fax
        self.zip_code = copy_public_address.zip_code
        self.address = copy_public_address.address
        self.mobile_tel = copy_public_address.mobile_tel
        self.memo = copy_public_address.memo
        self.official_position = copy_public_address.official_position
        self.company_name = copy_public_address.company_name
        self.company_kana = copy_public_address.company_kana
        self.company_tel = copy_public_address.company_tel
        self.company_fax = copy_public_address.company_fax
        self.company_zip_code = copy_public_address.company_zip_code
        self.company_address = copy_public_address.company_address
      end
    end
  end

  def validate_attributes
    if easy_entry # from Ajax
      if !email.blank? && !name.blank?
        if self.class.find(:first, :conditions => {:user_id => Core.user.id, :email => email})
          errors.add :base, "既に登録されています。"
        else
          self.name  = CGI.unescapeHTML(name.to_s) if escaped
          self.name  = name.gsub(/^"(.*)"$/, '\\1')
          self.email = email
        end
      end
    end
    
    self.name = name.gsub(/["<>]/, '') if !name.blank?
    
    to_kana = lambda {|str| str.to_s.tr("ぁ-ん", "ァ-ン") }
    self.kana = to_kana.call(kana)
    self.company_kana = to_kana.call(company_kana)
  end
  
  def self.user_addresses
    self.find(:all, :conditions => {:user_id => Core.user.id})  
  end
  
  def readable
    self.and :user_id, Core.user.id
    self
  end

  def readable?
    user_id == Core.user.id
  end

  def editable?
    #return true if Core.user.has_auth?(:manager)
    user_id == Core.user.id
  end
  
  def deletable?
    #return true if Core.user.has_auth?(:manager)
    user_id == Core.user.id
  end
  
  def search(params)
    
    like_param = lambda do |s|
      s.gsub(/[\\%_]/) {|r| "\\#{r}"}
    end
    
    params.each do |k, vs|
      next if vs.blank?
      
      vs.split(/[ 　]+/).each do |v|
        next if v == ''
        case k
        when 's_group_id'
          if v == NO_GROUP
            self.and :group_id, 'IS', nil
          else
            self.and :group_id, v
          end  
        when 's_name'
          self.and :name, 'LIKE', "%#{like_param.call(v)}%"
        when 's_email'
          self.and :email, 'LIKE', "%#{like_param.call(v)}%"
        when 's_name_or_kana'
          kana_v = v.to_s.tr("ぁ-ん", "ァ-ン")
          cond = Condition.new
          cond.or :name, 'LIKE', "%#{like_param.call(v)}%"
          cond.or :kana, 'LIKE', "%#{like_param.call(kana_v)}%"
          self.and cond
        end
      end
    end
  end

  def sorted_groups
    self.groups.sort do |g1, g2|
      names1 = g1.parents_tree_names
      names2 = g2.parents_tree_names
      comp = 0
      (0..([names1.size, names2.size].max - 1)).each do |i|
        comp = names1[i].to_s <=> names2[i].to_s
        break if comp != 0
      end
      comp
    end
  end

  # === CSVインポート確認画面で重複表示するためのアドレスのインスタンスを作成するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_provisional_exist_address
    self.provisional_exist_address = Gw::WebmailAddress.where(user_id: Core.user.id, email: self.email).first
  end

  class << self

    # === アドレス帳グループに対し抽出結果の1件を取得する、1件もなければインスタンスを生成するメソッド
    #
    # ==== 引数
    #  * target_name: 抽出対象のグループ名
    #  * target_level_no: 抽出対象の階層レベル
    #  * target_all_parent_names: 抽出対象のグループを含めた親グループ名
    #  * book: nil
    # ==== 戻り値
    #  Gw::WebmailAddressGroup
    def group_first_or_new(target_name, target_level_no, target_all_parent_names, book = nil)
      extract_target_groups = Gw::WebmailAddressGroup.where(user_id: Core.user.id)
      result_extract = self.group_first_and_parent_id_from_import_csv(
        extract_target_groups, target_level_no, target_all_parent_names)

      # 個人アドレス帳の最上位(root)グループのIDは0
      parent_group_id = result_extract[:parent_group_id].to_i
      target_group = result_extract[:target_group]

      target_group = Gw::WebmailAddressGroup.new(user_id: Core.user.id, name: target_name,
        level_no: target_level_no, parent_id: parent_group_id) if target_group.blank?

      return target_group
    end

  end

protected

  def save_groups

    gids = self.in_groups ? self.in_groups.split(",").collect{|id| id.to_i} : []
    grps = self.groupings;
    
    grps.each do |g|
      if idx = gids.index(g.group_id)
        gids.delete_at(idx)
      else
        g.destroy()
      end
    end
    
    gids.each do |gid|
      group = Gw::WebmailAddressGroup.new.readable
      group.and 'id', gid
      group.and 'user_id', Core.user.id
      group = group.find(:first)
      self.groupings << Gw::WebmailAddressGrouping.new({
        :address_id => id,
        :group_id => gid
      }) if group
    end
  end
  
end
