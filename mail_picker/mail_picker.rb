require 'net/pop'
require 'rubygems'
require 'trac4r'
require 'tmail'
require 'nkf'
require 'yaml'


CONF_FILE = File.expand_path(File.dirname(__FILE__)) + '/mail_picker.conf'
IDS_FILE  = File.expand_path(File.dirname(__FILE__)) + '/mail_picker.dat'
LOG_FILE  = File.expand_path(File.dirname(__FILE__)) + '/mail_picker.log'


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
                    :login_user,
                    :login_password,
                    :trac_url,
                    :target_mail_from ]


class HinemosTrac

  @@conf = Hash.new

#
# main procedure
#
  def self.main

    $hinemosTracLog = HinemosTracLog.new

    read_conf
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

        trac = Trac.new(@@conf[:trac_url] + TRAC_URL_SUFFIX, @@conf[:trac_user_id], @@conf[:trac_user_password])

        option_field_list = @@conf[:option_fields_fix] == nil ? Hash.new :
                                                                @@conf[:option_fields_fix]

        mail_parser = HinemosMailParser.new(t_mail.body.to_s, t_mail.date)
        
        get_mapping_field_list(@@conf.keys).each do |mapping_field|

          mapping_value =  mail_parser.get_trac_value(@@conf, mapping_field)

          next if mapping_value == nil

          option_field_list.store(mapping_field, mapping_value)

        end
        
        mail_subject = MAIL_ENCODER.call(t_mail.subject.to_s)
        mail_body = MAIL_ENCODER.call(t_mail.body.to_s)

        begin
          t_id = trac.tickets.create(mail_subject, mail_body, option_field_list)
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
# reading the configuration file
#
  def self.read_conf

    begin
    file = open(CONF_FILE)
    rescue
      $hinemosTracLog.puts_message "Failure to open the conf file (#{CONF_FILE})"
      return
    else
      $hinemosTracLog.puts_message "Success to open the conf file (#{CONF_FILE})"
    end
    while line = file.gets do
      next if line =~ /^#.*/ || line.chomp == ''

      line_key = line.sub(/#{CONF_SEPARATOR}.+$/, '').chomp
      line_value = change_type(line.sub(/^.+#{CONF_SEPARATOR}/, '').chomp)

      if line_key =~ /\./
        parent_key = line_key.sub(/\..+$/,'')
        child_key = line_key.sub(/^[^\.]+\./,'')

        parent_value = @@conf[parent_key.to_sym] == nil ?
                        { child_key => line_value } :
                        @@conf[parent_key.to_sym].merge({ child_key => line_value})

        @@conf.store parent_key.to_sym, parent_value

      else

        @@conf.store line_key.to_sym, line_value
      end
    end
    file.close
  end

#
# change the valiable data type
#
  def self.change_type(string)

    if string =~ /^\d+$/
      return string.to_i

    elsif string =~ /^true$/
      return true

    elsif string =~ /^false$/
      return false

    else
      return string

    end

  end

#
# check the mail if it's target
#
  def self.target_mail?(t_mail)

    mail_from_regular_expression = @@conf[:target_mail_from].gsub(/\s/,'\\s').gsub(/\,/, '|')
    if t_mail.from.to_s =~ /#{mail_from_regular_expression}/

      unless t_mail.subject.to_s =~ /^(RE:)|(FW:).*/i
     
        subject_regular_expression = @@conf[:target_mail_subject].empty? ? 
                                       '.+' : 
              			       @@conf[:target_mail_subject]

        subject_regular_expression = subject_regular_expression.gsub(/\$\{[^}]+\}/,'.*').gsub(/\s/,'\\s').gsub(/\,/, '|')
        if t_mail.subject.to_s =~ /^#{subject_regular_expression}$/
          return true
        end
      end
    end
    return false
  end

  def self.get_mapping_field_list(conf_keys)
    mapping_keys = Array.new
    conf_keys.each do |key|
      if key.to_s =~ /^#{CONF_MAPPING_HEADER}[^_]+$/
        mapping_keys.push(key.to_s.sub(/^#{CONF_MAPPING_HEADER}/, "").to_sym)
      end
    end
    return mapping_keys
  end



end

class HinemosTracLog
  attr_accessor :log_file


  def initialize
    @log_file = open(LOG_FILE, "a") if IS_NEED_LOG_FILE
  end

  def puts_message(message)
    log_message = DateTime.now.strftime("%Y/%m/%d %H:%M:%S") + " " + message
    @log_file.puts(log_message) if IS_NEED_LOG_FILE
    puts(log_message) 
  end

  def finalize
    @log_file.close if IS_NEED_LOG_FILE
  end

end


#
# check if the mail has created
#
class MailDuplicateChecker

  attr_accessor :unique_id_list

  def initialize
    begin
      ids_file = File.open(IDS_FILE)
    rescue
      $hinemosTracLog.puts_message("Failure to open the mail id file (#{IDS_FILE}) that has finished creating the ticket.")
      return
    else
      $hinemosTracLog.puts_message("Success to open the mail id file (#{IDS_FILE}).")
    end

    @unique_id_list = Array.new
    while line = ids_file.gets do
      @unique_id_list.push(line.chomp) unless line.empty?
    end
    ids_file.close
  end

#
# check if ticket has created
#
  def has_created_ticket?(unique_id)
    unique_id_list.include?(unique_id)
  end


#
# write the unique id of the mail that has created ticket in the file
#
  def write_id(unique_id)
    begin
      ids_file = open(IDS_FILE, "a")
      ids_file.puts(unique_id)
      ids_file.close
    rescue
      return false
    end
    unique_id_list.push(unique_id)
    return true
  end

end

class HinemosMailParser

  attr_accessor :body_hash

  def initialize(body, date)
    @body_hash = Hash.new
    parse(body)
    @body_hash.store('original_mail_date', date)
  end
  
  def parse(body)
    utf8_body = MAIL_ENCODER.call(body)
    utf8_body.split(/[\r\n]{1,2}/).each do |line|
      next unless line =~ /#{MAIL_SEPARATOR}/
      raw_key = line.sub(/#{MAIL_SEPARATOR}.+$/, "").strip
      raw_value = line.sub(/^.+#{MAIL_SEPARATOR}/, "").strip

      next if raw_key.empty? || raw_value.empty?

      @body_hash.store(raw_key, raw_value)
    end

  end

  def get_trac_value(conf, trac_item_name)

    conf_name = CONF_MAPPING_HEADER + trac_item_name.to_s

    hinemos_item_name = conf[conf_name.to_sym]
    raw_value = @body_hash[hinemos_item_name]

    return nil if raw_value == nil

    if conf["#{conf_name}_values".to_sym] == nil
      parse_option = conf["#{conf_name}_parse".to_sym]
      if parse_option == nil
        return raw_value
      else
        return "" if raw_value.empty?

	      REG_SIGN.keys.each do |sign|
	        parse_option = parse_option.sub(/\$\{#{sign.to_s}\}/,REG_SIGN[sign])
	      end
        begin
          parsed = DateTime.parse(raw_value)
        rescue
          $hinemosTracLog.puts_message("Failure to parse about #{raw_value}.Please check this date format.")
        return nil
      end
	#return parsed.strftime(parse_pattern) 
	return parsed.strftime(parse_option)
      end
    else
      mapping_value = conf["#{conf_name}_values".to_sym].invert
      return mapping_value[raw_value]
    end
  end
end

HinemosTrac.main
