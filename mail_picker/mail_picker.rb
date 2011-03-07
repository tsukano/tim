require 'net/pop'
require 'rubygems'
require 'trac4r'

# for windows.Because it's difficult for installing tmail in windows.
require 'action_mailer' unless ( RUBY_PLATFORM =~ /linux$/ )
require 'tmail'
require 'nkf'
require 'yaml'

ex_path = File.expand_path(File.dirname(__FILE__))

require ex_path + '/lib/batch_log'
require ex_path + '/mail/mail_duplicate_checker'
require ex_path + '/mail/mail_parser'
require ex_path + '/lib/conf_util'

CONF_FILE = ex_path + '/mail_picker.conf'
IDS_FILE  = ex_path + '/mail_picker.dat'
LOG_FILE  = ex_path + '/mail_picker.log'

ORIGINAL_MAIL_DATE = "original_mail_date"

IS_NEED_LOG_FILE = true 

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
                    :login_user,
                    :login_password,
                    :trac_url,
                    :target_mail_from ]


#class HinemosTrac

module MailPicker

#
# main procedure
#
  def main

    $hinemosTracLog = BatchLog.new(IS_NEED_LOG_FILE)

    @@conf = ConfUtil.read_conf
    return if @@conf.empty? == true
    
    MUST_WRITE_CONF.each do |conf_field|

      if @@conf[conf_field] == nil || 
         @@conf[conf_field].blank?
        $hinemosTracLog.puts_message "Caution. You must write configuration about #{conf_field}."
        return
      end
    end

    @mail_duplicate_checker = MailDuplicateChecker.new 
    return if @mail_duplicate_checker.unique_id_list == nil # not found the file

    pop = Net::POP3.new(@@conf[:mail_server_address], 
                        @@conf[:mail_server_port])

    begin
      pop.start(@@conf[:login_user], 
                @@conf[:login_password])
    rescue
      $hinemosTracLog.puts_message "Failure to access the pop server. Please check pop server configuration. "
      return
    else
      $hinemosTracLog.puts_message "Success to access the pop server."
    end


    pop.mails.each do |mail|
      t_mail = TMail::Mail.parse(mail.pop)
    
      if target_mail?(t_mail)

        next if @mail_duplicate_checker.has_created_ticket?(mail.unique_id)

        $hinemosTracLog.puts_message "The Mail (#{t_mail.subject}) is target for creating ticket."

        trac = Trac.new(@@conf[:trac_url] + TRAC_URL_SUFFIX,
        				@@conf[:trac_user_id], 
        				@@conf[:trac_user_password])

        option_field_list = @@conf[:option_fields_fix] == nil ? Hash.new :
                                                                @@conf[:option_fields_fix]

        mail_parser = MailParser.new(t_mail.body.to_s,
        							 t_mail.date.to_s)
        
        ConfUtil.get_mapping_field_list(@@conf.keys).each do |mapping_field|

          mapping_value =  mail_parser.get_trac_value(@@conf, mapping_field)

          next if mapping_value == nil

          option_field_list.store(mapping_field, mapping_value)

        end
        
        mail_subject = MAIL_ENCODER.call(t_mail.subject.to_s)
        mail_body = MAIL_ENCODER.call(t_mail.body.to_s)

        begin
          t_id = trac.tickets.create(mail_subject, 
          							 mail_body, 
          							 option_field_list)
        rescue
          $hinemosTracLog.puts_message "Failure to create ticket to the trac server.Please Check trac server configuration."
          break
        else
          $hinemosTracLog.puts_message "Success to create ticket ( id = #{t_id} )"
        end

        if @@conf[:mail_delete_enable]
          mail.delete
          $hinemosTracLog.puts_message "The mail was deleted in pop server."

        else
          writted_success = @mail_duplicate_checker.write_id(mail.unique_id)
          if writted_success
            $hinemosTracLog.puts_message "Success to write the mail id to the file."
          else
            $hinemosTracLog.puts_message "Failure to write the mail id to the file."
            break
          end
        end
      end
    end

    pop.finish
    $hinemosTracLog.puts_message "Finished accessing the pop server."

    $hinemosTracLog.finalize
  end


#
# check the mail if it's target
#
  def target_mail?(t_mail)

    mail_from_regular_expression = @@conf[:target_mail_from].gsub(/\s/,'\\s').gsub(/\,/, '|')
    if t_mail.from.to_s =~ /#{mail_from_regular_expression}/

      unless t_mail.subject.to_s =~ /^(RE:)|(FW:).*/i
     
        subject_regular_expression = @@conf[:target_mail_subject].empty? ? 
                                       '.+' : 
              			       		 @@conf[:target_mail_subject]

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

  module_function :main

end


MailPicker.main
