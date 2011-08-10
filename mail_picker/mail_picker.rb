# -*- coding: utf-8 -*-

require 'net/pop'
require 'rubygems'
#require 'trac4r'

require 'nkf'
require 'yaml'
require 'rexchange'
require "thread"


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
CONF_CUSTOM_FIELD_ID_HEADER = "custom_field_id_"

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

#class HinemosTrac

module MailPicker

#
# main procedure
#
  def main

#    $hinemosTracLog = BatchLog.new(IS_NEED_LOG_FILE)

    conf = ConfUtil.read_conf

    return if conf.empty?

#    RedmineClient::Base.configure do
#      self.site = conf[:redmine_url]
#      self.user = conf[:redmine_user_id]
#      self.password = conf[:redmine_user_password]
#    end
    mapping_fields = ConfUtil.get_mapping_field_list(conf.keys)

#    MUST_WRITE_CONF.each do |conf_field|
#      if conf[conf_field] == nil || conf[conf_field].blank?
#        $hinemosTracLog.puts_message "Caution. You must write configuration about #{conf_field}."
#        return
#      end
#    end

#    mail_duplicate_checker = MailDuplicateChecker.new 
#    return if mail_duplicate_checker.message_id_list == nil # not found the file

	  begin
	    
	    if conf[:information_get_mode] == 0
	      p 'mail'
        require 'action_mailer' 
        require 'tmail'
        
	      mail_session = MailSession.new(conf)
	      mail_session.tmail_list.each_with_index do |t_mail, i|
          next if t_mail.subject.index(conf[:target_mail_title]) != 0
          mail_subject = MAIL_ENCODER.call(t_mail.subject.to_s)
          mail_body = t_mail.body.to_s

          regist_issue(mail_subject, mail_body, conf, mapping_fields)
        end
        mail_session.finalize
	    else
	      p 'zabbixapi'
	      require 'zabbixapi'
	      zbx = Zabbix::ZabbixApi.new(conf[:zabbix_url], conf[:zabbix_user_id], conf[:zabbix_user_password])
	      h = zbx.get_host_id('s-ibs-portal-stg01')
	      
	      message_get_alert = { 
          :method => 'alert.get', 
          :params => { 
             :output => 'extend', 
          }, 
          :auth => zbx.auth 
        }
        alerts = zbx.do_request(message_get_alert)

#################################################################################################################
        alerts.each_with_index do |alert, i|
          p alert
          mail_subject = alert["subject"].to_s
          next if mail_subject.index(conf[:target_mail_title]) != 0
          
          mail_body = alert["message"]

            p 'thread'
            regist_issue(mail_subject, mail_body, conf, mapping_fields)
    
        end
#################################################################################################################

	    end
#	    $hinemosTracLog.puts_message "Failure to access the mail server. Please check mail server configuration. "
	    return
	  else
#	    $hinemosTracLog.puts_message "Success to access the mail server."
	  end
	end

    # Issue model on the client side
#    mail_session.tmail_list.each_with_index do |t_mail, i|

#  	  next if t_mail.subject.index(conf[:target_mail_title]) != 0

#      mail_body = t_mail.body.to_s

#      if MailPicker.target_mail?(t_mail, conf)
#        next if mail_duplicate_checker.has_created_ticket?(t_mail.message_id)

#        $hinemosTracLog.puts_message "The Mail (#{t_mail.subject}) is target for creating ticket."

#        trac = Trac.new(conf[:trac_url] + TRAC_URL_SUFFIX,
#        								conf[:trac_user_id], 
#        								conf[:trac_user_password])
    def regist_issue(mail_subject, mail_body, conf, mapping_fields)
      require 'redmine_client'
      RedmineClient::Base.configure do
        self.site = conf[:redmine_url]
        self.user = conf[:redmine_user_id]
        self.password = conf[:redmine_user_password]
      end
      custom_fields = Hash.new
        
#        mail_parser = MailParser.new( t_mail.body.to_s,
#        															t_mail.date.to_s)

      mail_body.each_line do |line|
        mapping_fields.each do |mapping_field|
          if line.index(conf[(CONF_MAPPING_HEADER + mapping_field).to_sym]) == 0
             parse_mapping_value =  /#{conf[(CONF_MAPPING_HEADER + mapping_field).to_sym]} = /.match(line)
              
            next if parse_mapping_value == nil
#              custom_field_list.store(mapping_field.to_sym, parse_mapping_value.post_match.rstrip)
            if mapping_field == 'trigger_value' then
                  custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,
                                      get_trigger_value_to_conf(parse_mapping_value.post_match.rstrip, conf))
            elsif mapping_field == 'trigger_nseverity' then
                  custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,
                                      get_trigger_nseverity_to_conf(parse_mapping_value.post_match.rstrip, conf))
            elsif mapping_field == 'date' then
                  date = parse_mapping_value.post_match.rstrip
                  custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s, date.gsub('.', '-'))
            elsif mapping_field == 'event_date' then
                  event_date = parse_mapping_value.post_match.rstrip
                  custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s, event_date.gsub('.', '-'))           
            else
                  custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,parse_mapping_value.post_match.rstrip)
            end
          end
        end
      end
      # event id is registed
      if custom_fields[conf[:custom_field_id_trigger_value].to_s].to_s == conf[:off_event].to_s
        p 'update'
        search_event_id = 'cf_' + conf[:custom_field_id_off_event_id].to_s
      else
        p 'post'
        search_event_id = 'cf_' + conf[:custom_field_id_event_id].to_s
      end
      issues = RedmineClient::Issue.find(:first,
                :params => {
                   search_event_id.to_sym => custom_fields[conf[:custom_field_id_event_id].to_s].to_i
                })

      if issues != nil
        puts "not covered EVENT.ID=" + custom_fields[conf[:custom_field_id_event_id].to_s]
        return
      end

      if !check_and_update(custom_fields, conf)

        issue = RedmineClient::Issue.new(
          :subject => mail_subject,
          :description => mail_body,
          :project_id => conf[:regist_project_id],
          :custom_field_values => custom_fields
        )
        
        begin
          if issue.save
            puts 'POST Issue ID=' +
                 issue.id
          else
            p 'error'
#             puts issue.errors.full_messages
          end
        rescue
#            $hinemosTracLog.puts_message "Failure to create ticket to the trac server.Please Check trac server configuration."
#            break
        else
#            $hinemosTracLog.puts_message "Success to create ticket ( id = #{issue.id} )"
        end
      end
#        if conf[:pop_mail_delete_enable] && mail_session.pop?
#          mail_session.delete_pop_mail(i)
#          $hinemosTracLog.puts_message "The mail was deleted in mail server."

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
    end
    

#   $hinemosTracLog.puts_message "Finished accessing the mail server."

#    $hinemosTracLog.finalize


#
# update issue
#
  def check_and_update(custom_fields, conf)
    if custom_fields[conf[:custom_field_id_trigger_value].to_s].to_s == conf[:off_event].to_s
      search_hostname = 'cf_' + conf[:custom_field_id_hostname].to_s
      search_trigger_id = 'cf_' + conf[:custom_field_id_trigger_id].to_s
  
      issues = RedmineClient::Issue.find(:all,
                :params => {
                   search_hostname.to_sym => custom_fields[conf[:custom_field_id_hostname].to_s],
                   search_trigger_id.to_sym => custom_fields[conf[:custom_field_id_trigger_id].to_s].to_i
                })
  
      issues.each do |issue|
        custom_field_trigger_value = issue.custom_fields.select{|elem| elem.name == conf[:mapping_trigger_value]}
        if custom_field_trigger_value[0].value != conf[:off_event].to_s
          set_custom_field(issue, conf[:mapping_off_event_id], custom_fields[conf[:custom_field_id_event_id].to_s])
          set_custom_field(issue, conf[:mapping_trigger_value], custom_fields[conf[:custom_field_id_trigger_value].to_s])
          set_custom_field(issue, conf[:mapping_trigger_name], custom_fields[conf[:custom_field_id_trigger_name].to_s])
  
          if issue.save
            puts 'UPDATE Issue ID=' +
                 issue.id
            return true
          end
        end
      end
    end
    return false
  end
  
  def set_custom_field(issue, name, value)
    issue.custom_fields.each do |custom_field|
      if custom_field.name == name
        custom_field.value = value
      end
    end
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

  def get_trigger_value_to_conf(value, conf)
    str = conf[('trigger_value_' + value.to_s).to_sym]
    if str == nil
      return value
    end
    return str
  end
  
  def get_trigger_nseverity_to_conf(value, conf)
    str = conf[('trigger_nseverity_' + value.to_s).to_sym]
    if str == nil
      return value
    end
    return str
  end

  module_function :main, :check_and_update, :set_custom_field, :target_mail?, :get_trigger_value_to_conf, :get_trigger_nseverity_to_conf, :regist_issue
end

MailPicker.main
