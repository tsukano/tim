class MailParser

  ZABBIX_NORMAL_TRIGGER_VALUE = "0"
  ZABBIX_NORMAL_TRIGGER_STATUS = "1"
  ZABBIX_NORMAL_STATUS = "1"

  attr_accessor :raw_body
  attr_accessor :cf_values

  def initialize(utf8_body, separator, cf_mapping, is_change_type)
    self.raw_body = Hash.new
    parse(utf8_body, separator)
    self.cf_values = Hash.new
    cf_convert(cf_mapping["cf_id"], 
               cf_mapping["cf_value"],
               cf_mapping["cf_translated"],
               is_change_type)
  end

  def recovered_zabbix?(conf_item_list_zabi_recover, conf)
    conf_item_list_zabi_recover.each do |conf_item|
      value_in_mail = self.cf_values[conf["cf_id"][conf_item].to_s]
      next if value_in_mail == nil
      normal_raw = self.class.const_get("ZABBIX_NORMAL_#{conf_item.upcase}")
      normal_value = conf["cf_value"][conf_item][normal_raw]
      return true if value_in_mail == normal_value
    end
    return false
  end

  def get_cf(item_name)
    return self.cf_values[item_name]
  end

  def add_cf(cf_id, cf_value)
    self.cf_values.store(cf_id.to_s, cf_value.to_s)
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

  def cf_convert(conf_id, conf_value, conf_translated, is_change_type)
    translation = conf_translated.invert
    self.raw_body.each do |raw_key, raw_value|
      config_item_name = translation[raw_key] == nil ?
                           raw_key.downcase.gsub(/[\-\.\s]/, '_') :
                           translation[raw_key] 
      cf_id = conf_id[config_item_name]
      next if cf_id == nil
      if conf_value[config_item_name] != nil
        cf_value = conf_value[config_item_name][raw_value]
      else
        if is_change_type && config_item_name.end_with?('id')
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
