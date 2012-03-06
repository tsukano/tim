# -*- coding: utf-8 -*-

require 'net/pop'
require 'rubygems'

require 'nkf'
require 'yaml'
require 'rexchange'
require 'thread'
require 'time' 
require 'tmail'
require 'redmine_client'

ex_path = File.expand_path(File.dirname(__FILE__))

require ex_path + '/lib/batch_log'
require ex_path + '/mail/mail_duplicate_checker'
require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/conf_util'
require ex_path + '/lib/redmine_controller'

CONF_FILE = ex_path + '/../setting.conf'
IDS_FILE  = ex_path + '/mail_picker.dat'
LOG_FILE  = ex_path + '/mail_picker.log'

#ORIGINAL_MAIL_DATE = "original_mail_date"

IS_NEED_LOG_FILE = false 

CONF_MAPPING_HEADER = "mapping_"
CONF_CUSTOM_FIELD_ID_HEADER = "custom_field_id_"

MAIL_SEPARATOR = "\s+[:：]\s+"
CONF_SEPARATOR = "\s?=\s?"

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
  def self.main

    conf = ConfUtil.read_conf
    return if conf.empty?

#    mapping_fields = ConfUtil.get_mapping_field_list(conf.keys)

	  begin
      redmine = RedmineController.new(conf[:redmine_url],
                                      conf[:redmine_user_id],
                                      conf[:redmine_user_password])
#	    tmail_list_and_custom_fields = Array.new

      tmail_list = Array.new
      case conf[:alert_type]
      when ConfUtil::ALERT_TYPE_MAIL
        mail_session = MailSession.new(conf[:mail_server_address], 
                                       conf[:pop_server_port],
                                       conf[:mail_server_user], 
                                       conf[:mail_server_password])
        tmail_list = mail_session.
                        get_recent_tmail_list(conf[:interval_seconds_before_now_for_checking_alert])
        mail_session = nil
        
      when ConfUtil::ALERT_TYPE_ZABBIX_API
        # TODO:API 
        # must start configured mail title
      end

	    tmail_list.each_with_index do |t_mail, i|

	      next unless MailSession.
                      target_mail?(t_mail,
                                   conf[:target_mail_subject_header])
        # check if redmine have been registered
        next if redmine.have_registerd?(t_mail[MailSession::TMAIL_IM_ALERT_ID],
                                        conf[:cf_id_im_alert_id],
                                        conf[:cf_id_im_recovered_alert_id])
        # issue instance making

        # update checking
        if is_recovered(t_mail.body)

        end
        # cf formating
        
        # redmine regist
	    end

      update_maching = Array.new
      tmail_list_and_custom_fields.each_with_index do |t_mail, i|

#        if conf[:information_get_mode] == 0
#          t_mail[:custom_fields] = cutting_massage(t_mail[:mail_subject], t_mail[:mail_body], conf, mapping_fields)
#        else
#          t_mail[:custom_fields] = cutting_massage(t_mail[:mail_subject], t_mail[:mail_body], conf, mapping_fields, t_mail[:mail_message_id])
#        end

        if t_mail[:custom_fields][conf[:custom_field_id_trigger_value].to_s].to_s == conf[:running_event].to_s
          map_index = i - 1
          while map_index > 0 do
            item = tmail_list_and_custom_fields[map_index]

            if (t_mail[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s == item[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s &&
              t_mail[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i == item[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i)

             update_map = Hash.new
              if conf[:information_get_mode] == 0
                update_map[conf[:custom_field_id_event_id].to_s] = item[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
                update_map[conf[:custom_field_id_running_event_id].to_s] = t_mail[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
              else
                update_map[conf[:custom_field_id_event_id].to_s] = item[:custom_fields][conf[:custom_field_id_message_id_mail_header].to_s].to_i
                update_map[conf[:custom_field_id_running_event_id].to_s] = t_mail[:custom_fields][conf[:custom_field_id_message_id_mail_header].to_s].to_i
              end
              update_map[conf[:custom_field_id_trigger_value].to_s] = t_mail[:custom_fields][conf[:custom_field_id_trigger_value].to_s]
              update_map[conf[:custom_field_id_trigger_name].to_s] = t_mail[:custom_fields][conf[:custom_field_id_trigger_name].to_s]
              
              update_maching.push(update_map)
              break
            end
            map_index = map_index -1
          end
        end
      end

      require 'redmine_client'
      multi_process(tmail_list_and_custom_fields, conf[:concurrency].to_i, nil) do |item, index| 
        RedmineClient::Base.configure do
          self.site = conf[:redmine_url]
          self.user = conf[:redmine_user_id]
          self.password = conf[:redmine_user_password]
        end
        regist_issue(item[:mail_subject], item[:mail_body], item[:custom_fields], conf, mapping_fields, update_maching)
      end
      mail_session.finalize
#	    else
#	      p 'zabbixapi'
#	      require 'zabbixapi'
#	      zbx = Zabbix::ZabbixApi.new(conf[:zabbix_url], conf[:zabbix_user_id], conf[:zabbix_user_password])
#	      
#	      message_get_alert = { 
#          :method => 'alert.get', 
#          :params => { 
#             :output => 'extend', 
#          }, 
#          :auth => zbx.auth 
#        }
#        update_maching = Array.new
#        alerts = zbx.do_request(message_get_alert)
#        alerts.each_with_index do |alert, i|
#          mail_subject = alert["subject"].to_s
#          next if mail_subject.index(conf[:target_mail_title]) != 0
#          
#          mail_body = alert["message"]
#
#          alert[:custom_fields] = cutting_massage(mail_subject, mail_body, conf, mapping_fields)
#
#          if alert[:custom_fields][conf[:custom_field_id_trigger_value].to_s].to_s == conf[:running_event].to_s
#            map_index = i - 1
#            while map_index > 0 do
#              item = alerts[map_index]
#
#              if (alert[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s == item[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s &&
#                alert[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i == item[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i)
#
#                update_map = Hash.new
#                update_map[conf[:custom_field_id_event_id].to_s] = item[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
#                update_map[conf[:custom_field_id_running_event_id].to_s] = alert[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
#                update_map[conf[:custom_field_id_trigger_value].to_s] = alert[:custom_fields][conf[:custom_field_id_trigger_value].to_s]
#                update_map[conf[:custom_field_id_trigger_name].to_s] = alert[:custom_fields][conf[:custom_field_id_trigger_name].to_s]
#                
#                update_maching.push(update_map)
#                break
#              end
#              map_index = map_index -1
#            end
#          end
#        end
#
#        require 'redmine_client'
#        multi_process(alerts, conf[:concurrency].to_i, nil) do |item, index| 
#          RedmineClient::Base.configure do
#            self.site = conf[:redmine_url]
#            self.user = conf[:redmine_user_id]
#            self.password = conf[:redmine_user_password]
#          end
#          regist_issue(item["subject"], item["message"], item[:custom_fields], conf, mapping_fields, update_maching)
#        end
#
#	    end
##	    $hinemosTracLog.puts_message "Failure to access the mail server. Please check mail server configuration. "
#	    return
#	  else
#	    $hinemosTracLog.puts_message "Success to access the mail server."
	  end
	end

  def cutting_massage(mail_subject, mail_body, conf, mapping_fields, massage_id = nil)
    custom_fields = Hash.new

    if massage_id != nil
      custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + "message_id_mail_header").to_sym].to_s, massage_id)
    end
    
    mail_body.each_line do |line|
      mapping_fields.each do |mapping_field|
        if line.index(conf[(CONF_MAPPING_HEADER + mapping_field).to_sym]) == 0
          parse_mapping_value =  /#{conf[(CONF_MAPPING_HEADER + mapping_field).to_sym]} : /.match(line)
          p conf[(CONF_MAPPING_HEADER + mapping_field).to_sym]
          p mapping_field
          p parse_mapping_value
          next if parse_mapping_value == nil
          if mapping_field == 'trigger_value' then
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,
                                    get_trigger_value_to_conf(parse_mapping_value.post_match.rstrip, conf))
          elsif mapping_field == 'trigger_nseverity' then
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,
                                    get_trigger_nseverity_to_conf(parse_mapping_value.post_match.rstrip, conf))
          elsif mapping_field == 'trigger_severity' then
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,
                                    get_trigger_severity_to_conf(parse_mapping_value.post_match.rstrip, conf))
          elsif mapping_field == 'priority_num' then
            p conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s
            p get_trigger_value_to_conf_for_hinemos(parse_mapping_value.post_match.rstrip, conf)
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,
                                    get_priority_num_to_conf(parse_mapping_value.post_match.rstrip, conf))
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + "trigger_value").to_sym].to_s,
                                    get_trigger_value_to_conf_for_hinemos(parse_mapping_value.post_match.rstrip, conf))
          elsif mapping_field == 'date' then
                date = parse_mapping_value.post_match.rstrip
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s, date.gsub('.', '-'))
          elsif mapping_field == 'event_date' then
                event_date = parse_mapping_value.post_match.rstrip
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s, event_date.gsub('.', '-'))
          elsif mapping_field == 'item_log_date' then
                item_log_date = parse_mapping_value.post_match.rstrip
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s, item_log_date.gsub('.', '-'))
          elsif mapping_field == 'generation_date' then
                generation_date = parse_mapping_value.post_match.rstrip
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s, generation_date.gsub('.', '-'))
          else
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + mapping_field).to_sym].to_s,parse_mapping_value.post_match.rstrip)
                p parse_mapping_value.post_match.rstrip
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
        if conf[:information_get_mode] == 2
          search_running_message_id_mail_header = 'cf_' + conf[:custom_field_id_running_message_id_mail_header].to_s
          
          issues = RedmineClient::Issue.find(:first,
                :params => {
                   search_running_message_id_mail_header.to_sym => custom_fields[conf[:custom_field_id_running_message_id_mail_header].to_s]
                })
          if issues != nil
            puts "not covered Message ID=" + custom_fields[conf[:custom_field_id_running_message_id_mail_header].to_s]
            return
          end
        else

          search_event_id = 'cf_' + conf[:custom_field_id_running_event_id].to_s
          
          issues = RedmineClient::Issue.find(:first,
                :params => {
                   search_event_id.to_sym => custom_fields[conf[:custom_field_id_event_id].to_s].to_i
                })
          if issues != nil
            puts "not covered EVENT.ID=" + custom_fields[conf[:custom_field_id_event_id].to_s]
            return
          end
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
            if conf[:information_get_mode] == 2
              set_custom_field(issue, conf[:mapping_running_id_mail_header], custom_fields[conf[:custom_field_running_id_mail_header].to_s])
              set_custom_field(issue, conf[:mapping_trigger_value], custom_fields[conf[:custom_field_id_trigger_value].to_s])
              set_custom_field(issue, conf[:mapping_trigger_name], custom_fields[conf[:custom_field_id_trigger_name].to_s])
            else
              set_custom_field(issue, conf[:mapping_running_event_id], custom_fields[conf[:custom_field_id_event_id].to_s])
              set_custom_field(issue, conf[:mapping_trigger_value], custom_fields[conf[:custom_field_id_trigger_value].to_s])
              set_custom_field(issue, conf[:mapping_trigger_name], custom_fields[conf[:custom_field_id_trigger_name].to_s])
            end
    
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
      
      if conf[:information_get_mode] == 2
        search_message_id_mail_header = 'cf_' + conf[:custom_field_id_message_id_mail_header].to_s
        
        issues = RedmineClient::Issue.find(:first,
                  :params => {
                     search_message_id_mail_header.to_sym => custom_fields[conf[:custom_field_id_message_id_mail_header].to_s]
                  })
        search_id = custom_fields[conf[:custom_field_id_message_id_mail_header].to_s]
      else
        search_event_id = 'cf_' + conf[:custom_field_id_event_id].to_s
        
        issues = RedmineClient::Issue.find(:first,
                  :params => {
                     search_event_id.to_sym => custom_fields[conf[:custom_field_id_event_id].to_s].to_i
                  })
        search_id = custom_fields[conf[:custom_field_id_event_id].to_s].to_i
      end
      if issues != nil
        puts "not covered EVENT.ID=" + search_id.to_s
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
        if conf[:information_get_mode] == 2
          serch_map_event_id = custom_fields[conf[:custom_field_id_message_id_mail_header].to_s].to_s
          
          if item[conf[:custom_field_id_event_id].to_s].to_s == serch_map_event_id
  
            search_event_id = 'cf_' + conf[:custom_field_id_running_message_id_mail_header].to_s
  
            issues = RedmineClient::Issue.find(:first,
                  :params => {
                     search_event_id.to_sym => item[conf[:custom_field_id_running_event_id].to_s].to_i
                  })
  
            if issues != nil
              puts "not covered EVENT.ID=" + item[conf[:custom_field_id_running_event_id].to_s].to_s
              return
            end
  
            search_event_id = 'cf_' + conf[:custom_field_id_message_id_mail_header].to_s
            update_issue = RedmineClient::Issue.find(:all,
                  :params => {
                     search_event_id.to_sym => item[conf[:custom_field_id_event_id].to_s].to_i
                  })
            update_issue.each do |issue|
   
              set_custom_field(issue, conf[:mapping_running_message_id_mail_header], item[conf[:custom_field_id_running_event_id].to_s].to_s)
              set_custom_field(issue, conf[:mapping_trigger_value], item[conf[:custom_field_id_trigger_value].to_s])
              set_custom_field(issue, conf[:mapping_trigger_name], item[conf[:custom_field_id_trigger_name].to_s])
             
              if issue.save
#                  puts 'UPDATE Issue ID=' +
#                       issue.id
                break
              else
                p 'error'
#                  puts issue.errors.full_messages
                break
              end
            end
          end
        else
          serch_map_event_id = custom_fields[conf[:custom_field_id_event_id].to_s].to_s
          
          if item[conf[:custom_field_id_event_id].to_s].to_s == serch_map_event_id
  
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
#                  puts 'UPDATE Issue ID=' +
#                       issue.id
                break
              else
                p 'error'
#                  puts issue.errors.full_messages
                break
              end
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

  def get_trigger_value_to_conf(value, conf)
    str = conf[('trigger_value_' + value.to_s).to_sym]
    if str == nil
      return value
    end
    return str
  end
  
  def get_trigger_value_to_conf_for_hinemos(value, conf)
    str = conf[('priority_to_trigger_value_' + value.to_s).to_sym]
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
  
  def get_trigger_severity_to_conf(value, conf)
    str = conf[('trigger_severity_' + value.to_s).to_sym]
    if str == nil
      return value
    end
    return str
  end
  
  def get_priority_num_to_conf(value, conf)
    str = conf[('priority_num_' + value.to_s).to_sym]
    if str == nil
      return value
    end
    return str
  end
  
  def multi_process(ary, concurrency, qsize) 
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
  end

end

MailPicker.main
