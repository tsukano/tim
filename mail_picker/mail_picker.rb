# -*- coding: utf-8 -*-

require 'net/pop'
require 'rubygems'
#require 'trac4r'
require 'redmine_client'

require 'action_mailer' 
require 'tmail'
require 'nkf'
require 'yaml'
require 'rexchange'


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

RedmineClient::Base.configure do
  self.site = 'http://172.17.1.206/redmine/'
  self.user = 'admin'
  self.password = 'admin'
  
  def self.inherited(child)
    child.headers['X-Redmine-Nometa'] = '1'
  end

end

#class HinemosTrac

module MailPicker

#
# main procedure
#
  def main

=begin
    mail_body = 
"EVENT.ID = 1234
EVENT.DATE = 20110622
NODE.ID = 1111
NODE.NAME = ibs
HOST.ID = 2233
HOSTNAME = ibs-portal
TRIGGER.ID = 5963
TRIGGER.NAME = サーバダウン
TRIGGER.VALUE = 2
TRIGGER.NSEVERITY = 5"
=end

#    $hinemosTracLog = BatchLog.new(IS_NEED_LOG_FILE)

#    conf = ConfUtil.read_conf
#    return if conf.empty?
    conf = {
        :mail_server_address => 'november-steps.net',
        :pop_server_port => 110,
        :mail_server_user => "admin",
        :mail_server_password => "",
        :mail_receive_method => "pop",

        :mapping_event_id => 'EVENT.ID',
        :mapping_event_date => 'EVENT.DATE',
        :mapping_node_id => 'NODE.ID',
        :mapping_node_name => 'NODE.NAME',
        :mapping_host_id => 'HOST.ID',
        :mapping_hostname => 'HOSTNAME',
        :mapping_trigger_id => 'TRIGGER.ID',
        :mapping_trigger_name => 'TRIGGER.NAME',
        :mapping_trigger_value => 'TRIGGER.VALUE',
        :mapping_trigger_nseverity => 'TRIGGER.NSEVERITY',
        
        :error_trigger_value =>'1',
        
        :regist_project_id => '1',
        
        :custom_field_id_event_id => '5',
        :custom_field_id_event_date => '6',
        :custom_field_id_node_id => '7',
        :custom_field_id_node_name => '8',
        :custom_field_id_host_id => '9',
        :custom_field_id_hostname => '10',
        :custom_field_id_trigger_id => '11',
        :custom_field_id_trigger_name => '12',
        :custom_field_id_trigger_value => '13',
        :custom_field_id_trigger_nseverity => '14'
    }
#    MUST_WRITE_CONF.each do |conf_field|
#      if conf[conf_field] == nil || conf[conf_field].blank?
#        $hinemosTracLog.puts_message "Caution. You must write configuration about #{conf_field}."
#        return
#      end
#    end

#    mail_duplicate_checker = MailDuplicateChecker.new 
#    return if mail_duplicate_checker.message_id_list == nil # not found the file

	  begin
	  	mail_session = MailSession.new(conf)
	  rescue
#	    $hinemosTracLog.puts_message "Failure to access the mail server. Please check mail server configuration. "
	    return
	  else
#	    $hinemosTracLog.puts_message "Success to access the mail server."
	  end

    # Issue model on the client side
    mail_session.tmail_list.each_with_index do |t_mail, i|
	  next unless t_mail.subject == "対象となるタイトル"
      mail_body = t_mail.body.to_s
      

#      if MailPicker.target_mail?(t_mail, conf)
#        next if mail_duplicate_checker.has_created_ticket?(t_mail.message_id)

#        $hinemosTracLog.puts_message "The Mail (#{t_mail.subject}) is target for creating ticket."

#        trac = Trac.new(conf[:trac_url] + TRAC_URL_SUFFIX,
#        								conf[:trac_user_id], 
#        								conf[:trac_user_password])

        custom_field_list = Hash.new
        
#        mail_parser = MailParser.new( t_mail.body.to_s,
#        															t_mail.date.to_s)

        mapping_fields = [
                  'EVENT.ID',
                  'EVENT.DATE',
                  'NODE.ID',
                  'NODE.NAME',
                  'HOST.ID',
                  'HOSTNAME',
                  'TRIGGER.ID',
                  'TRIGGER.NAME',
                  'TRIGGER.VALUE',
                  'TRIGGER.NSEVERITY'
        ]
#        ConfUtil.get_mapping_field_list(conf.keys).each do |mapping_field|

        mail_body.each_line do |line| 
          mapping_fields.each do |mapping_field|

            parse_mapping_value =  /#{mapping_field} = /.match(line)

            next if parse_mapping_value == nil
  
            custom_field_list.store(mapping_field, parse_mapping_value.post_match.rstrip)
          end
        end

#        mail_subject = MAIL_ENCODER.call(t_mail.subject.to_s)
#        mail_body = MAIL_ENCODER.call(t_mail.body.to_s)
        

        custom_fields = {conf[:custom_field_id_event_id] => custom_field_list[conf[:mapping_event_id]],
                 conf[:custom_field_id_event_date] => custom_field_list[conf[:mapping_event_date]],
                 conf[:custom_field_id_node_id] => custom_field_list[conf[:mapping_node_id]],
                 conf[:custom_field_id_node_name] => custom_field_list[conf[:mapping_node_name]],
                 conf[:custom_field_id_host_id] => custom_field_list[conf[:mapping_host_id]],
                 conf[:custom_field_id_hostname] => custom_field_list[conf[:mapping_hostname]],
                 conf[:custom_field_id_trigger_id] => custom_field_list[conf[:mapping_trigger_id]],
                 conf[:custom_field_id_trigger_name] => custom_field_list[conf[:mapping_trigger_name]],
                 conf[:custom_field_id_trigger_value] => custom_field_list[conf[:mapping_trigger_value]],
                 conf[:custom_field_id_trigger_nseverity] => custom_field_list[conf[:mapping_trigger_nseverity]]
        }
        if !check_and_update(custom_fields, conf)
          puts 'update false'
return
          mail_subject = get_subject_by_custom_fields(custom_fields, conf)
          issue = RedmineClient::Issue.new(
            :subject => mail_subject,
            :project_id => conf[:regist_project_id],
            :custom_field_values => custom_fields
          )
  
          begin
            if issue.save
              puts issue.id
            else
              puts issue.errors.full_messages
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
    
    mail_session.finalize

#   $hinemosTracLog.puts_message "Finished accessing the mail server."

#    $hinemosTracLog.finalize
  end

#
# update issue
#
  def check_and_update(custom_fields, conf)
    
    puts 'update in'
    
    search_subject = get_subject_by_custom_fields(custom_fields, conf)
    issues = RedmineClient::Issue.find(:all,
              :params => {
                 :subject => search_subject
              })

    issues.each do |issue|
      custom_field_trigger_value = issue.custom_fields.select{|elem| elem.name == conf[:mapping_trigger_value]}
      if custom_field_trigger_value[0].value == '2'
        set_custom_field(issue, conf[:mapping_trigger_value], custom_fields[conf[:custom_field_id_trigger_value]])

        return issue.save
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

  def get_subject_by_custom_fields(custom_fields, conf)
    subject = custom_fields[conf[:custom_field_id_hostname]] +
              '_' +
              custom_fields[conf[:custom_field_id_trigger_id]]
    p subject
    return subject
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

  module_function :main, :check_and_update, :set_custom_field, :get_subject_by_custom_fields, :target_mail?

end

MailPicker.main
