class MailSession
  # caution:this date is written by mail send client_side.so, must be exact time.
  MAIL_HEADER_DATE_LINE = /Date\s?\:\s?([^\r\n]+)\r\n/
  TMAIL_IM_ALERT_ID = 'im_alert_id'

	attr_accessor :pop
	
	def initialize(address, port, user, password)
    self.pop = Net::POP3.new(address, port)	

    self.pop.start(user, password)
	end

	def finalize
		self.pop.finish
	end

  def get_recent_tmail_list(interval_seconds)
    time_from = Time.now - interval_seconds
    tmail_list = Array.new
    # reversing is for perfomance
    self.pop.mails.reverse.each do |mail|
      p "now checking mail id = " + mail.unique_id
      mail_send_time = time_from
      mail.header.scan(MAIL_HEADER_DATE_LINE) do |date_in_header|
        mail_send_time = Time.parse(date_in_header[0])
        p " Date :" + mail_send_time.to_s
      end
      if time_from < mail_send_time
        tmail = TMail::Mail.parse(mail.mail)
        tmail.store(TMAIL_IM_ALERT_ID, mail.unique_id)
        tmail_list.unshift(tmail)
      else
        p "stop reading pop mail for over interval"
        break
      end
    end
    return tmail_list
  end
end
