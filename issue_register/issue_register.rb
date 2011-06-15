#!ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'redmine_client'

# Issue model on the client side
RedmineClient::Base.configure do
  self.site = 'http://172.17.1.206:3000/'# 定数ファイルで宣言する
  self.user = 'admin'# 定数ファイルで宣言する
  self.password = 'admin'# 定数ファイルで宣言する
end

# スタブ
  incident_tracker_id = 1     # トラッカーID
  incident_subject = 'subject'       # 題名
  incident_status_id = 1      # ステータスID
  incident_project_id = 1     # プロジェクトID
  incident_description = 'description' #説明
  incident_author_to_id = 1    # 登録ユーザID
  incident_custom1 = RedmineClient::Issue::CustomField.new(
    :name => 'custom_text',
    :value => 'test_text')
  incident_custom2 = RedmineClient::Issue::CustomField.new(
    :name => 'custom_int',
    :value => 12345)
#  :priority_id => 1    # 登録ユーザID
#                        # 親チケット
#  :assigned_to_id => 1  # 担当者
#                        # カテゴリ
#                        # 対象バージョン
#  :start_date => 1,     # 開始日
#  :done_ratio => 1,     # 期日
#  :due_date => 1        # 予定工数

# issueにセットして登録する
issue = RedmineClient::Issue.new(
  :tracker_id => incident_tracker_id,     # トラッカーID
  :subject => incident_subject,       # 題名
  :status_id => incident_status_id,      # ステータスID
  :project_id => incident_project_id,     # プロジェクトID
  :description => incident_description, #説明
  :author_to_id => incident_author_to_id,    # 登録ユーザID
#  :priority_id => 1    # 優先度ID
#                        # 親チケット
#  :assigned_to_id => 1  # 担当者
#                        # カテゴリ
#                        # 対象バージョン
#  :start_date => 1,     # 開始日
#  :done_ratio => 1,     # 期日
#  :due_date => 1        # 予定工数
  :custom_fields => {'1' => 'Fixed'}
)
if issue.save
  puts issue.id
else
  puts issue.errors.full_messages
end

