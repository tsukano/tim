require 'net/pop'
require 'nkf'
require 'rubygems'
require 'tmail'

class MailSession

  MAIL_ENCODER = Proc.new{|string| NKF.nkf('-w',string)}
  # caution:this date is written by mail send client_side.so, must be exact time.
  MAIL_HEADER_DATE_LINE = /Date\s?\:\s?([^\r\n]+)\r\n/
  TMAIL_IM_ALERT_ID = 'im_alert_id'

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

  def get_recent_tmail_list(interval_seconds, subject_header)
    time_from = Time.now - interval_seconds
    tmail_list = Array.new
    # reversing is for perfomance reason
    self.pop.mails.reverse.each do |mail|
      p "* now checking mail id = " + mail.unique_id
      tmail_header = TMail::Mail.parse(MAIL_ENCODER.call(mail.header))
      if recent_date?(tmail_header.date, time_from)
        if tmail_header.subject.start_with?(subject_header)
          tmail = TMail::Mail.parse(MAIL_ENCODER.call(mail.mail))
          tmail.store(TMAIL_IM_ALERT_ID, mail.unique_id)
          tmail_list.unshift(tmail)
        end
      else
        p " >>> stop reading pop mail for over interval"
        break
      end
    end
    return tmail_list
  end
  private
  def recent_date?(mail_date, time_from)
    # TODO: world time
    mail_date != nil && time_from < mail_date
  end
end
