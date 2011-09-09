# -*- coding: utf-8 -*-

require 'net/pop'
require 'rubygems'

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

    conf = ConfUtil.read_conf

    return if conf.empty?

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
	    
	    if conf[:information_get_mode] != 1
	      p 'mail'
        require 'action_mailer' 
        require 'tmail'
        
	      mail_session = MailSession.new(conf)
	      tmail_list_and_custom_fields = Array.new
	      mail_session.tmail_list.each_with_index do |t_mail, i|
	        tmail_and_custom_fields = Hash.new
	        tmail_and_custom_fields[:mail_subject] = MAIL_ENCODER.call(t_mail.subject.to_s)
	        tmail_and_custom_fields[:mail_body] = t_mail.body.to_s
	        tmail_and_custom_fields[:mail_message_id] = t_mail.message_id
	        tmail_and_custom_fields[:custom_fields] = Hash.new

	        tmail_list_and_custom_fields.push(tmail_and_custom_fields)
	      end
=begin          next if t_mail.subject.index(conf[:target_mail_title]) != 0
          mail_subject = MAIL_ENCODER.call(t_mail.subject.to_s)
          mail_body = t_mail.body.to_s

          regist_issue(mail_subject, mail_body, conf, mapping_fields)
        end
=end
        update_maching = Array.new
        tmail_list_and_custom_fields.each_with_index do |t_mail, i|
          next if t_mail[:mail_subject].index(conf[:target_mail_title]) != 0

          if conf[:information_get_mode] == 0
            t_mail[:custom_fields] = cutting_massage(t_mail[:mail_subject], t_mail[:mail_body], conf, mapping_fields)
          else
            t_mail[:custom_fields] = cutting_massage(t_mail[:mail_subject], t_mail[:mail_body], conf, mapping_fields, t_mail[:mail_message_id])
          end

          if t_mail[:custom_fields][conf[:custom_field_id_trigger_value].to_s].to_s == conf[:running_event].to_s
            map_index = i - 1
            while map_index > 0 do
              item = tmail_list_and_custom_fields[map_index]

              if (t_mail[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s == item[:custom_fields][conf[:custom_field_id_hostname].to_s].to_s &&
                t_mail[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i == item[:custom_fields][conf[:custom_field_id_trigger_id].to_s].to_i)

                update_map = Hash.new
                update_map[conf[:custom_field_id_event_id].to_s] = item[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
                update_map[conf[:custom_field_id_running_event_id].to_s] = t_mail[:custom_fields][conf[:custom_field_id_event_id].to_s].to_i
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
	    else
	      p 'zabbixapi'
	      require 'zabbixapi'
	      zbx = Zabbix::ZabbixApi.new(conf[:zabbix_url], conf[:zabbix_user_id], conf[:zabbix_user_password])
	      
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

        require 'redmine_client'
        multi_process(alerts, conf[:concurrency].to_i, nil) do |item, index| 
          RedmineClient::Base.configure do
            self.site = conf[:redmine_url]
            self.user = conf[:redmine_user_id]
            self.password = conf[:redmine_user_password]
          end
          regist_issue(item["subject"], item["message"], item[:custom_fields], conf, mapping_fields, update_maching)
        end

	    end
#	    $hinemosTracLog.puts_message "Failure to access the mail server. Please check mail server configuration. "
	    return
	  else
#	    $hinemosTracLog.puts_message "Success to access the mail server."
	  end
	end

  def cutting_massage(mail_subject, mail_body, conf, mapping_fields, massage_id = nil)
    custom_fields = Hash.new

    if massage_id != nil
      p massage_id
    end
    
    mail_body.each_line do |line|b
      mapping_fields.each do |mapping_field|
        if line.index(conf[(CONF_MAPPING_HEADER + mapping_field).to_sym]) == 0
          parse_mapping_value =  /#{conf[(CONF_MAPPING_HEADER + mapping_field).to_sym]} = /.match(line)

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
                custom_fields.store(conf[(CONF_CUSTOM_FIELD_ID_HEADER + "event_id").to_sym].to_s,
                                    make_event_id(generation_date, conf))
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
        if conf[:information_get_mode] == 2
          search_event_id = 'cf_' + conf[:custom_field_id_running_message_id_mail_header].to_s
          
          issues = RedmineClient::Issue.find(:first,
                :params => {
                   search_event_id.to_sym => custom_fields[conf[:custom_field_id_running_message_id_mail_header].to_s]
                })
        else

          search_event_id = 'cf_' + conf[:custom_field_id_running_event_id].to_s
          
          issues = RedmineClient::Issue.find(:first,
                :params => {
                   search_event_id.to_sym => custom_fields[conf[:custom_field_id_event_id].to_s].to_i
                })
        end
        
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
        search_event_id = 'cf_' + conf[:custom_field_id__message_id_mail_header].to_s
        
        issues = RedmineClient::Issue.find(:first,
                  :params => {
                     search_event_id.to_sym => custom_fields[conf[:custom_field_id__message_id_mail_header].to_s]
                  })
      else
        search_event_id = 'cf_' + conf[:custom_field_id_event_id].to_s
        
        issues = RedmineClient::Issue.find(:first,
                  :params => {
                     search_event_id.to_sym => custom_fields[conf[:custom_field_id_event_id].to_s].to_i
                  })
      end
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

  module_function :main, :check_update_maching,:cutting_massage, :set_custom_field, :target_mail?,:get_trigger_value_to_conf,
   :get_trigger_nseverity_to_conf, :get_trigger_severity_to_conf,:get_priority_num_to_conf, :regist_issue, :multi_process
end

MailPicker.main
