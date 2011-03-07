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

	def finalize
		@pop.finish if pop?
	end


	private

	def change_to_tmail
		if pop?
			@pop.mails.each do |mail|
        self.tmail_list.push TMail::Mail.parse(mail.pop)
      end
		elsif exchange?
			@rexchange.folders.values[0].each do |message|
				tmail = TMail::Mail.new
				tmail.from = message.from
				tmail.to   = message.to
				tmail.subject = message.subject
				tmail.body = message.body
				tmail.date = message.attributes["urn:schemas:httpmail:date"]
				self.tmail_list.push tmail
			end
		end
	end


	def pop?
		self.mail_method != nil && self.mail_method == METHOD_POP
	end
	
	def exchange?
		self.mail_method != nil && self.mail_method == METHOD_EXCHANGE
	end
end