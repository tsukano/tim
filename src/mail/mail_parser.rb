class MailParser

  ZABBIX_NORMAL_TRIGGER_VALUE = "0"
  ZABBIX_NORMAL_TRIGGER_STATUS = "1"
  ZABBIX_NORMAL_STATUS = "1"

  attr_accessor :raw_str
  attr_accessor :raw_body
  attr_accessor :cf_id_values

  def initialize(utf8_body, separator, cf_mapping, null_value, is_change_type)
    self.raw_str = utf8_body
    self.raw_body = Hash.new
    parse(utf8_body, separator)
    self.cf_id_values = Hash.new
    cf_convert(cf_mapping["cf_id"], 
               cf_mapping["cf_value"],
               cf_mapping["cf_translated"],
               null_value,
               is_change_type)
  end

  def recovered_zabbix?(conf_item_list_zabi_recover, conf)
    conf_item_list_zabi_recover.each do |conf_item|
      value_in_mail = self.cf_id_values[conf["cf_id"][conf_item].to_s]
      next if value_in_mail == nil
      normal_raw = self.class.const_get("ZABBIX_NORMAL_#{conf_item.upcase}")
      normal_value = conf["cf_value"][conf_item][normal_raw]
      return true if value_in_mail == normal_value
    end
    return false
  end

  def get_cf(item_name)
    return self.cf_id_values[item_name]
  end

  def add_cf(cf_id, cf_value)
    self.cf_id_values.store(cf_id.to_s, cf_value.to_s)
  end

  def get_part_of_cf(item_name_list, conf_id)
    cf_conditions = Hash.new
    item_name_list.each do |item|
      cf_id = conf_id[item]
      raise "you must write id of #{item} in config file" if cf_id == nil
      cf_value = get_cf(cf_id)
      next if cf_value == nil
      cf_conditions.store(cf_id, cf_value)
    end
    return cf_conditions
  end
  
  private

  def parse(utf8_body, separator)
    separator = Regexp.escape(separator)
    utf8_body.split(/[\r\n]{1,2}/).each do |line|
      if line =~ /^([^#{separator}]+)[#{separator}](.+)$/
        raw_key   = $1.strip
        raw_value = $2.strip
        next if raw_key.empty? || raw_value.empty?
        self.raw_body.store(raw_key, raw_value)
      end
    end
  end

  def cf_convert(conf_id, conf_value, conf_translated, null_value, is_change_type)
    return if conf_id == nil
    translation = conf_translated.invert
    self.raw_body.each do |raw_key, raw_value|
      next if null_value != nil && raw_value == null_value
      config_item_name = translation[raw_key] == nil ?
                           raw_key.downcase.gsub(/[\-\.\s]/, '_') :
                           translation[raw_key] 
      cf_id = conf_id[config_item_name]
      next if cf_id == nil
      if conf_value != nil && conf_value[config_item_name] != nil
        cf_value = conf_value[config_item_name][raw_value]
        cf_value = raw_value if cf_value == nil
      else
        if is_change_type && config_item_name.end_with?('_id')
          cf_value = raw_value.to_i
        elsif is_change_type && config_item_name.end_with?('date')
          cf_value = raw_value.gsub('.','-')
        else 
          cf_value = raw_value
        end
      end
      add_cf(cf_id, cf_value)
    end
  end
end
