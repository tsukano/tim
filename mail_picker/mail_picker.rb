#!ruby
# -*- coding: utf-8 -*-

#require 'net/pop'
require 'rubygems'
#require 'trac4r'
require 'redmine_client'
#require 'json'
#require 'zabbixapi'

# for windows.Because it's difficult for installing tmail in windows.
#require 'action_mailer' unless ( RUBY_PLATFORM =~ /linux$/ )
#require 'tmail'
#require 'nkf'
#require 'yaml'
#require 'rexchange'
#require 'savon'


ex_path = File.expand_path(File.dirname(__FILE__))

require ex_path + '/lib/batch_log'
require ex_path + '/mail/mail_duplicate_checker'
require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/conf_util'

CONF_FILE = ex_path + '/mail_picker.conf'
IDS_FILE  = ex_path + '/mail_picker.dat'
LOG_FILE  = ex_path + '/mail_picker.log'

ORIGINAL_MAIL_DATE = "original_mail_date"

IS_NEED_LOG_FILE = false 

CONF_MAPPING_HEADER = "mapping_"

MAIL_SEPARATOR = "\s+[:：]\s+"
CONF_SEPARATOR = "\s?=\s?"

MAIL_ENCODER = Proc.new{|string| NKF.nkf('-w',string)}
TRAC_URL_SUFFIX = "/xmlrpc"

REG_SIGN = {:year   => '%Y',
            :month  => '%m', 
            :day    => '%d', 
            :hour   => '%H', 
            :minute => '%M', 
            :second => '%S'}

MUST_WRITE_CONF = [ :mail_server_address,
                    :mail_server_user,
                    :mail_server_password,
                    :trac_url,
                    :target_mail_from ]

#RedmineClient::Base.configure do
#  self.site = 'http://172.17.1.206:3000/redmine/'# 定数ファイルで宣言する
#  self.user = 'admin'# 定数ファイルで宣言する
#  self.password = 'admin'# 定数ファイルで宣言する
#end
    
#class HinemosTrac

module MailPicker

#
# main procedure
#
  def main
    RedmineClient::Base.configure do
      self.site = 'http://172.17.1.206/redmine/'# 定数ファイルで宣言する
      self.user = 'admin'# 定数ファイルで宣言する
      self.password = 'admin'# 定数ファイルで宣言する
    end
    
#    zbx = Zabbix::ZabbixApi.new('http://172.17.1.207/zabbix/', 'admin', 'zabbix')
#    hostid = zbx.get_host_id('portal-stg01')
    
#    p hostid
#    $hinemosTracLog = BatchLog.new(IS_NEED_LOG_FILE)

#    conf = ConfUtil.read_conf
#    return if conf.empty?
    
#    MUST_WRITE_CONF.each do |conf_field|
#      if conf[conf_field] == nil || conf[conf_field].blank?
#        $hinemosTracLog.puts_message "Caution. You must write configuration about #{conf_field}."
#        return
#      end
#    end

#    mail_duplicate_checker = MailDuplicateChecker.new 
#    return if mail_duplicate_checker.message_id_list == nil # not found the file

#	  begin
#	  	mail_session = MailSession.new(conf)
#	  rescue
#	    $hinemosTracLog.puts_message "Failure to access the mail server. Please check mail server configuration. "
#	    return
#	  else
#	    $hinemosTracLog.puts_message "Success to access the mail server."
#	  end

# Redmine対応
# 登録内容のスタブ

    regist_list = [
      {
        :tracker_id => 1, 
        :subject => 'subject1',
        :status_id => 1,
        :project_id => 1,
        :description=> 'description1',
        :author_to_id => 1,
        :custon1 => 'custom_text',
        :custom2 => 12345,
        :custom3 => 'Monday',
        :custom4 => '2011-07-25'
      } , 
      {
        :tracker_id => 1, 
        :subject => 'subject2',
        :status_id => 1,
        :project_id => 1,
        :description => 'description2',
        :author_to_id => 1,
        :custon1 => 'custom_text',
        :custom2 => 6789,
        :custom3 => 'Tuesday',
        :custom4 => '2011-07-30'
      }
    ]

# Issue model on the client side
    regist_list.each do |regist|

      issue = RedmineClient::Issue.new(
        :tracker_id => regist[:tracker_id],     # トラッカーID
        :subject => regist[:subject],           # 題名
        :status_id => regist[:status_id],      # ステータスID
        :project_id => regist[:project_id],     # プロジェクトID
        :description => regist[:description], #説明
        :author_to_id => regist[:author_to_id] # 登録ユーザID
      )

#      puts issue
#      issue.save
      # カスタムフィールドの入力
#      custom1 = issue.custom_fields[0]
#      custom1.value = regist[:custon1]
#      custom2 = issue.custom_fields[1]
#      custom2.value = regist[:custon2]
#      custom3 = issue.custom_fields[2]
#      custom3.value = regist[:custon3]
#      custom4 = issue.custom_fields[3]
#      custom4.value = regist[:custon4]
      if issue.save
        puts issue.id
      else
        puts issue.errors.full_messages
      end
    end

#    mail_session.tmail_list.each_with_index do |t_mail, i|
#      if MailPicker.target_mail?(t_mail, conf)
#        next if mail_duplicate_checker.has_created_ticket?(t_mail.message_id)
#
#        $hinemosTracLog.puts_message "The Mail (#{t_mail.subject}) is target for creating ticket."
#
#        trac = Trac.new(conf[:trac_url] + TRAC_URL_SUFFIX,
#       								conf[:trac_user_id], 
#        								conf[:trac_user_password])
#
#        option_field_list = conf[:option_fields_fix] == nil ?
#                              Hash.new                      :
#                              conf[:option_fields_fix]
#
#        mail_parser = MailParser.new( t_mail.body.to_s,
#        															t_mail.date.to_s)
#        
#        ConfUtil.get_mapping_field_list(conf.keys).each do |mapping_field|
#
#          mapping_value =  mail_parser.get_trac_value(conf, 
#          																						mapping_field)
#
#          next if mapping_value == nil
#
#          option_field_list.store(mapping_field, mapping_value)
#
#        end
#        
#        mail_subject = MAIL_ENCODER.call(t_mail.subject.to_s)
#        mail_body = MAIL_ENCODER.call(t_mail.body.to_s)
#
#        begin
#          t_id = trac.tickets.create(mail_subject, 
#          							 mail_body, 
#          							 option_field_list)
#        rescue
#          $hinemosTracLog.puts_message "Failure to create ticket to the trac server.Please Check trac server configuration."
#          break
#        else
#          $hinemosTracLog.puts_message "Success to create ticket ( id = #{t_id} )"
#        end
#
#        if conf[:pop_mail_delete_enable] && mail_session.pop?
#          mail_session.delete_pop_mail(i)
#          $hinemosTracLog.puts_message "The mail was deleted in mail server."
#
#        else
#          writted_success = mail_duplicate_checker.write_id(t_mail.message_id)
#          if writted_success
#            $hinemosTracLog.puts_message "Success to write the mail id to the file."
#          else
#            $hinemosTracLog.puts_message "Failure to write the mail id to the file."
#            break
#          end
#        end
#      end
#    end
    
#    mail_session.finalize

#    $hinemosTracLog.puts_message "Finished accessing the mail server."

#    $hinemosTracLog.finalize
  end


#
# check the mail if it's target
#
  def target_mail?(t_mail, conf)

    mail_from_regular_expression = conf[:target_mail_from].gsub(/\s/,'\\s').gsub(/\,/, '|')
    if t_mail.from.to_s =~ /#{mail_from_regular_expression}/

      unless t_mail.subject.to_s =~ /^(RE:)|(FW:).*/i
     
        subject_regular_expression = conf[:target_mail_subject].empty? ? 
                                       '.+' : 
              			       		 conf[:target_mail_subject]

        subject_regular_expression = subject_regular_expression.
        								gsub(/\$\{[^}]+\}/,'.*').
        								gsub(/\s/,'\\s').
        								gsub(/\,/, '|')
        if t_mail.subject.to_s =~ /^#{subject_regular_expression}$/
          return true
        end
      end
    end
    return false
  end

  module_function :main, :target_mail?

end

MailPicker.main
