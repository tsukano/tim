class MailParser

  attr_accessor :body_hash

  def initialize(body, date)
    @body_hash = Hash.new
    parse(body)
    @body_hash.store(ORIGINAL_MAIL_DATE, date)
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
