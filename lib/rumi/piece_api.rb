# coding: utf-8
class Rumi::PieceApi < Rumi::AbstractApi

  # === ヘッダーメニュー取得メソッド
  #  ヘッダーのアイコン情報等を取得する
  # ==== 引数
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  # ==== 戻り値
  #  APIへのリクエスト結果(Stringオブジェクト)
  def header_menus(user_code, password)
    url = Enisys::Config.application["gw.root_url"]
    return nil if url.blank?

    action_url = "/api/header_menus"
    queries = { account: user_code, password: password }

    return request_api(URI.parse(url), action_url, queries)
  end


  # === メール管理者情報取得メソッド
  #  ヘッダーのアイコン情報等を取得する
  # ==== 引数
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  # ==== 戻り値
  #  APIへのリクエスト結果(Stringオブジェクト)
  def mail_admin(user_id, user_code, password)
    url = Enisys::Config.application["gw.root_url"]
    return nil if url.blank?

    action_url = "/api/mail_admin"
    queries = { id: user_id, account: user_code, password: password }

    return request_api(URI.parse(url), action_url, queries)
  end

  class << self

    # Rumi::PieceApi#header_menusの呼び出し元メソッド
    def header_menus(user_code, password)
      return self.new.header_menus(user_code, password)
    end

    # Rumi::PieceApi#mail_adminの呼び出し元メソッド
    def mail_admin(user_id, user_code, password)
      return self.new.mail_admin(user_id, user_code, password)
    end
  end

end
