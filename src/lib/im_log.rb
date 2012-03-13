require 'logger'

class ImLog
  def self.logger(is_stdout, is_file, filepath)
    if is_stdout
      logger = Logger.new(STDOUT)
    elsif is_file
      logger = Logger.new(filepath, 'daily')
    end
    logger.formatter = Logger::Formatter.new
    logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    return logger
  end
end
