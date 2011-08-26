# -*- coding: utf-8 -*-

require 'net/pop'
require 'rubygems'
#require 'trac4r'

require 'nkf'
require 'yaml'
require 'rexchange'
require 'thread'
require 'time' 

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
#    p start_time
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
#	      h = zbx.get_host_id(conf[:host_id].to_s)
	      
	      message_get_alert = { 
          :method => 'alert.get', 
          :params => { 
             :output => 'extend', 
          }, 
          :auth => zbx.auth 
        }
        update_maching = Array.new
        alerts = zbx.do_request(message_get_alert)
        alerts.each_with_index do |alert, i|
          mail_subject = alert["subject"].to_s
          next if mail_subject.index(conf[:target_mail_title]) != 0
          
          mail_body = alert["message"]

          alert[:custom_fields] = cutting_massage(mail_subject, mail_body, conf, mapping_fields)

          if alert[:custom_fields][conf[:custom_field_id_trigger_value].to_s].to_s == conf[:running_event].to_s
            map_index = i - 1
            while map_index > 0 do
              item = alerts[map_index]

              if (alert[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s == item[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s &&
                 alert[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i == item[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i)

                update_map = Hash.new
                update_map[conf[:custom_field_id_event_id].to_s] = item[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
                update_map[conf[:custom_field_id_running_event_id].to_s] = alert[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
                update_map[conf[:custom_field_id_trigger_value].to_s] = alert[:custom_fields][conf[:custom_field_id_trigger_value].to_s]
                update_map[conf[:custom_field_id_trigger_name].to_s] = alert[:custom_fields][conf[:custom_field_id_trigger_name].to_s]
                
                update_maching.push(update_map)
                break
              end
              map_index = map_index -1
            end
          end
        end

#################################################################################################################
        require 'redmine_client'
#        RedmineClient::Base.configure do
#          self.site = conf[:redmine_url]
#          self.user = conf[:redmine_user_id]
#          self.password = conf[:redmine_user_password]
#        end
#        alerts.each_with_index do |item, index| 
        multi_process(alerts) do |item, index| 
          RedmineClient::Base.configure do
            self.site = conf[:redmine_url]
            self.user = conf[:redmine_user_id]
            self.password = conf[:redmine_user_password]
          end
          regist_issue(item["subject"], item["message"], item[:custom_fields], conf, mapping_fields, update_maching)
        end

=begin
        alerts.each_with_index do |alert, i|
          mail_subject = alert["subject"].to_s
          next if mail_subject.index(conf[:target_mail_title]) != 0
          
          mail_body = alert["message"]

            regist_issue(mail_subject, mail_body, conf, mapping_fields)
    
        end
=end 
#################################################################################################################

	    end
#	    $hinemosTracLog.puts_message "Failure to access the mail server. Please check mail server configuration. "
	    return
	  else
#	    $hinemosTracLog.puts_message "Success to access the mail server."
	  end
	end

  def cutting_massage(mail_subject, mail_body, conf, mapping_fields)
    custom_fields = Hash.new

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
    return custom_fields
  end
    
  def regist_issue(mail_subject, mail_body, custom_fields, conf, mapping_fields, update_maching)
    # event id is registed
    if custom_fields[conf[:custom_field_id_trigger_value].to_s].to_s == conf[:running_event].to_s

      if !check_update_maching(custom_fields, conf, update_maching)
        p 'update'
        search_event_id = 'cf_' + conf[:custom_field_id_running_event_id].to_s
        
        issues = RedmineClient::Issue.find(:first,
              :params => {
                 search_event_id.to_sym => custom_fields[conf[:custom_field_id_event_id].to_s].to_i
              })

        if issues != nil
          puts "not covered EVENT.ID=" + custom_fields[conf[:custom_field_id_event_id].to_s]
          return
        end
        
        search_hostname = 'cf_' + conf[:custom_field_id_hostname].to_s
        search_trigger_id = 'cf_' + conf[:custom_field_id_trigger_id].to_s
    
        issues = RedmineClient::Issue.find(:all,
                  :params => {
                     search_hostname.to_sym => custom_fields[conf[:custom_field_id_hostname].to_s],
                     search_trigger_id.to_sym => custom_fields[conf[:custom_field_id_trigger_id].to_s].to_i,
                     search_event_id.to_sym => 0
                  })
    
        issues.each do |issue|
          custom_field_trigger_value = issue.custom_fields.select{|elem| elem.name == conf[:mapping_trigger_value]}
          if custom_field_trigger_value[0].value != conf[:running_event].to_s
            set_custom_field(issue, conf[:mapping_running_event_id], custom_fields[conf[:custom_field_id_event_id].to_s])
            set_custom_field(issue, conf[:mapping_trigger_value], custom_fields[conf[:custom_field_id_trigger_value].to_s])
            set_custom_field(issue, conf[:mapping_trigger_name], custom_fields[conf[:custom_field_id_trigger_name].to_s])
    
            if issue.save
#              puts 'UPDATE Issue ID=' +
#                   issue.id
            end
          end
        end

      else
        return
      end
    else
      p 'post'
      search_event_id = 'cf_' + conf[:custom_field_id_event_id].to_s
      
      issues = RedmineClient::Issue.find(:first,
                :params => {
                   search_event_id.to_sym => custom_fields[conf[:custom_field_id_event_id].to_s].to_i
                })
  
      if issues != nil
        puts "not covered EVENT.ID=" + custom_fields[conf[:custom_field_id_event_id].to_s]
      else
        issue = RedmineClient::Issue.new(
          :subject => mail_subject,
          :description => mail_body,
          :project_id => conf[:regist_project_id],
          :custom_field_values => custom_fields
        )
        begin
          if issue.save
#            puts 'POST Issue ID=' +
#                 issue.id
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
      
      update_maching.each do |item|
        # 更新マッピングが存在する場合更新する
        if item[conf[:custom_field_id_event_id].to_s].to_s == custom_fields[conf[:custom_field_id_event_id].to_s].to_s

          search_event_id = 'cf_' + conf[:custom_field_id_running_event_id].to_s
      
          issues = RedmineClient::Issue.find(:first,
                :params => {
                   search_event_id.to_sym => item[conf[:custom_field_id_running_event_id].to_s].to_i
                })

          if issues != nil
            puts "not covered EVENT.ID=" + item[conf[:custom_field_id_running_event_id].to_s].to_s
            return
          end

          search_event_id = 'cf_' + conf[:custom_field_id_event_id].to_s
          update_issue = RedmineClient::Issue.find(:all,
                :params => {
                   search_event_id.to_sym => item[conf[:custom_field_id_event_id].to_s].to_i
                })
          update_issue.each do |issue|
 
            set_custom_field(issue, conf[:mapping_running_event_id], item[conf[:custom_field_id_running_event_id].to_s].to_s)
            set_custom_field(issue, conf[:mapping_trigger_value], item[conf[:custom_field_id_trigger_value].to_s])
            set_custom_field(issue, conf[:mapping_trigger_name], item[conf[:custom_field_id_trigger_name].to_s])
           
            if issue.save
  #              puts 'UPDATE Issue ID=' +
  #                   issue.id
              break
            else
              p 'error'
  #              puts issue.errors.full_messages
              break
            end
          end
        end
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
  def check_update_maching(custom_fields, conf, update_maching)
    update_maching.each do |update_map|
      if custom_fields[conf[:custom_field_id_event_id].to_s].to_s == update_map[conf[:custom_field_id_running_event_id].to_s].to_s
        return true
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

  def multi_process(ary, concurrency = 2, qsize = nil) 
    q = (qsize) ? SizedQueue.new(qsize) : Queue.new
   
    producer = Thread.start(q, concurrency){|p_q, p_c| 
      ary.each_with_index do |item, index| 
        q.enq [ item, index, true] 
      end
   
      p_c.times{ q.enq [nil, nil, false] } 
    } 
   
   
    workers = [] 
    concurrency.times do
      workers << Thread.start(q){ |w_q| 
        task, index, flag = w_q.deq 
        while flag 
          yield task, index 
          task, index, flag = w_q.deq 
        end
      } 
    end
   
   
    producer.join 
    workers.each{|w| w.join } 
#    end_time = DateTime.now
#    p end_time
#    p (end_time - start_time)
  end

  module_function :main, :check_update_maching,:cutting_massage, :set_custom_field, :target_mail?,:get_trigger_value_to_conf, :get_trigger_nseverity_to_conf, :regist_issue, :multi_process
end

MailPicker.main
