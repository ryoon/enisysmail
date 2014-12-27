# encoding: utf-8
module Enisys
  def self.version
    "1.0.0"
  end
  
  def self.default_config
    { "application" => {
        "sys.login_footer"                       => "",
        "sys.mobile_footer"                      => "",
        "sys.session_expiration"                 => 24,
        "sys.session_expiration_for_mobile"      => 1,
        "sys.force_site"                         => "",
        "webmail.mailbox_quota_alert_rate"       => 0.85,
        "webmail.attachment_file_max_size"       => 5,
#        "webmail.attachment_file_upload_method"  => "flash",
        "webmail.show_only_ldap_user"            => 1,
        "webmail.filter_condition_max_count"     => 100,
        "webmail.mail_address_history_max_count" => 100,
#        "webmail.synchronize_mobile_setting"     => 0,
        "webmail.show_gw_schedule_link"          => 1,
        "webmail.max_file_name_length"           => 200,
        "webmail.mail_menu"                      => "メール",
        "webmail.mailbox_menu"                   => "フォルダ",
        "webmail.sys_address_menu"               => "組織アドレス帳",
        "webmail.address_group_menu"             => "個人アドレス帳",
        "webmail.public_address_book_menu"       => "共有アドレス帳",
        "webmail.filter_menu"                    => "フィルタ",
        "webmail.template_menu"                  => "テンプレート",
        "webmail.sign_menu"                      => "署名",
        "webmail.memo_menu"                      => "メモ",
        "webmail.tool_menu"                      => "ツール",
        "webmail.setting_menu"                   => "設定",
        "webmail.doc_menu"                       => "ヘルプ",
        "gw.root_url" => nil
    }}
  end
  
  def self.config
    $enisys_config ||= {}
    Enisys::Config
  end
  
  class Enisys::Config
    def self.application
      config = Enisys.default_config["application"]
      file   = "#{Rails.root}/config/application.yml"
      if ::File.exist?(file)
        yml = YAML.load_file(file)
        yml.each do |mod, values|
          values.each do |key, value|
            unless value.nil?
              if mod == "gw" && key == "root_url"
                begin
                  URI.parse(value)
                rescue
                  # 何もしない
                else
                  config["gw.root_url"] = value
                end
              else
                config["#{mod}.#{key}"] = value
              end
            end
          end if values
        end if yml
      end
      $enisys_config[:application] = config
    end
    
    def self.imap_settings
      $enisys_config[:imap_settings]
    end
    
    def self.imap_settings=(config)
      $enisys_config[:imap_settings] = config
    end
    
    def self.sso_settings
      $enisys_config[:sso_settings]
    end
    
    def self.sso_settings=(config)
      $enisys_config[:sso_settings] = config
    end
  end
end
