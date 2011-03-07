class MailSession
	
	METHOD_POP = 'pop'
	METHOD_EXCHANGE = 'exchange'
	
	attr_accessor :mail_method
	attr_accessor :tmail_list
	
	def initialize(conf)
		self.mail_method = conf[:mail_receive_method]
		self.tmail_list = Array.new

		if pop?
	    @pop = Net::POP3.new(conf[:mail_server_address], 
	                         conf[:pop_server_port])	

      @pop.start(conf[:mail_server_user], 
                 conf[:mail_server_password])
		elsif exchange?
			@rexchange = RExchange::open(conf[:mail_server_address],
																	 conf[:mail_server_user],
																	 conf[:mail_server_password])
		end
		change_to_tmail
	end


	def delete_pop_mail(index)
		count_has_deleted = tmail_list.size - @pop.size
		@pop.mails[index - count_has_deleted].delete
	end

	def finalize
		@pop.finish if pop?
	end

	def pop?
		self.mail_method != nil && self.mail_method == METHOD_POP
	end
	
	def exchange?
		self.mail_method != nil && self.mail_method == METHOD_EXCHANGE
	end


	private

	def change_to_tmail
		if pop?
			@pop.mails.each do |mail|
				tmail = TMail::Mail.parse(mail.pop)
				if tmail.message_id == nil
					tmail.message_id = tmail.unique_id
				end
        self.tmail_list.push tmail
      end
		elsif exchange?
			@rexchange.folders.values[0].each do |message|
				
				tmail = TMail::Mail.new
				tmail.from       = message.from
				tmail.to         = message.to
				tmail.subject    = message.subject
				tmail.body       = message.body
				tmail.date       = message.attributes["urn:schemas:httpmail:date"]
				tmail.message_id = message.attributes["urn:schemas:mailheader:message-id"]
				
				self.tmail_list.push tmail
			end
		end
	end


	
end