class ConfUtil
#
# reading the configuration file
#
  def self.read_conf

		conf = Hash.new

    begin
    file = open(CONF_FILE)
    rescue
#      $hinemosTracLog.puts_message "Failure to open the conf file (#{CONF_FILE})"
      return
    else
#      $hinemosTracLog.puts_message "Success to open the conf file (#{CONF_FILE})"
    end
    while line = file.gets do
      next if line =~ /^#.*/ || line.chomp == ''

      line_key = line.sub(/#{CONF_SEPARATOR}.+$/, '').chomp
      line_value = change_type(line.sub(/^.+#{CONF_SEPARATOR}/, '').chomp)

      if line_key =~ /\./
        parent_key = line_key.sub(/\..+$/,'')
        child_key = line_key.sub(/^[^\.]+\./,'')

        parent_value = conf[parent_key.to_sym] == nil ?
                        { child_key => line_value } :
                        conf[parent_key.to_sym].merge({ child_key => line_value})

        conf.store parent_key.to_sym, parent_value

      else

        conf.store line_key.to_sym, line_value
      end
    end
    file.close
    
    return conf
    
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

  def self.get_mapping_field_list(conf_keys)
    mapping_keys = Array.new
    conf_keys.each do |key|
      if key.to_s.index(CONF_MAPPING_HEADER) == 0
        mapping_keys.push(key.to_s.sub(/^#{CONF_MAPPING_HEADER}/, "").to_s)
#        mapping_keys.push(key.to_s)
      end
    end
    return mapping_keys
  end


end