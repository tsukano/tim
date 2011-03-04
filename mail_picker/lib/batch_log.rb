class BatchLog
  attr_accessor :log_file


  def initialize(is_need_log_file)
  	@is_need_log_file = is_need_log_file
    @log_file = open(LOG_FILE, "a") if @is_need_log_file
  end

  def puts_message(message)
    log_message = DateTime.now.strftime("%Y/%m/%d %H:%M:%S") + " " + message
    @log_file.puts(log_message) if @is_need_log_file
    puts(log_message) 
  end

  def finalize
    @log_file.close if @is_need_log_file
  end

end
