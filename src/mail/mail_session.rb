require 'net/pop'
require 'nkf'
require 'rubygems'
require 'tmail'

class MailSession

  MAIL_ENCODER = lambda {|string| NKF.nkf('-w',string)}
  TMAIL_IM_ALERT_ID = 'im_alert_id'
  TMAIL_IM_ORDER = "im_order"
  ESCAPE_HTML = lambda {|str| str.sub(/<\s?HTML.+\/\s?HTML\s?>/m, '')}

  attr_accessor :pop
	
  def initialize(conf)
    self.pop = Net::POP3.new(conf["address"], 
                             conf["port"])

    self.pop.start(conf["user"], 
                   conf["password"])
  end

  def finalize
    self.pop.finish
  end

  def get_recent_list(interval_seconds, subject_header)
    time_from = Time.now - interval_seconds
    tmail_list = Array.new
    # reversing is for perfomance reason
    self.pop.mails.reverse.each do |mail|
      $logger.info "* now checking mail id = " + mail.unique_id
      tmail_header = TMail::Mail.parse(MAIL_ENCODER.call(mail.header))
      if recent_date?(tmail_header.date, time_from)
        if tmail_header.subject.start_with?(subject_header)
          escaped_mail = ESCAPE_HTML.call(mail.mail)
          tmail = TMail::Mail.parse(MAIL_ENCODER.call(escaped_mail))
          tmail.store(TMAIL_IM_ALERT_ID, mail.unique_id)
          tmail.store(TMAIL_IM_ORDER, mail.number)
          tmail_list.unshift(tmail)
          $logger.info " >>> have set target tmail list"
        end
      else
        $logger.info " >>> stop reading pop mail for over interval"
        break
      end
    end
    return tmail_list
  end
  def self.convert_faked_tmail(alert_id, subject, message)
    tmail = TMail::Mail.new
    tmail.subject = subject
    tmail.body = message
    tmail.store(TMAIL_IM_ALERT_ID, alert_id)
    tmail.store(TMAIL_IM_ORDER, alert_id)
    return tmail
  end
  private
  def recent_date?(mail_date, time_from)
    # TODO: world time
    mail_date != nil && time_from < mail_date
  end
end
