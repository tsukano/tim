class MailParser

  ZABBIX_NORMAL_TRIGGER_VALUE = "0"
  ZABBIX_NORMAL_TRIGGER_STATUS = "1"
  ZABBIX_NORMAL_STATUS = "1"

  attr_accessor :raw_body
  attr_accessor :cf_values

  def initialize(utf8_body, cf_mapping)
    self.raw_body = Hash.new
    parse(utf8_body)
    self.cf_values = Hash.new
    cf_convert(cf_mapping["cf_id"], 
               cf_mapping["cf_value"],
               cf_mapping["cf_tlanslated"])
  end

  def recovered_hinemos?
    #TODO:
  end

  # only zabbix
  def recovered_zabbix?(conf_item_list_zabi_recover, conf)
    conf_id = conf['cf_id']
    conf_value = conf['cf_value']
    item_is_normal = lambda do |item|
                  value_in_mail = self.cf_values[conf_id[item].to_s]
                  return false if value_in_mail == nil
                  normal_value = conf_value[item][self.class.const_get(
                                                    "ZABBIX_NORMAL_" +
                                                    item.upcase)]
                  return value_in_mail == normal_value
    end
    conf_item_list_zabi_recover.each do |conf_item|
      return true if item_is_normal.call(conf_item) == true
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
  def parse(utf8_body)
    separator = Regexp.escape(MAIL_SEPARATOR)
    utf8_body.split(/[\r\n]{1,2}/).each do |line|
      if line =~ /^([^#{separator}]+)[#{separator}](.+)$/
        raw_key = $1.strip
        raw_value = $2.strip
        next if raw_key.empty? || raw_value.empty?
        self.raw_body.store(raw_key, raw_value)
      end
    end
  end

  def cf_convert(conf_id, conf_value, conf_tlanslated)
    tlanslation = conf_tlanslated.invert
    self.raw_body.each do |raw_key, raw_value|
      config_item_name = tlanslation[raw_key] == nil ?
                           raw_key.downcase.gsub(/[\-\.\s]/, '_') :
                           tlanslation[raw_key] 
      cf_id = conf_id[config_item_name]
      next if cf_id == nil
      cf_value = conf_value[config_item_name] == nil ? raw_value :
                                                       conf_value[config_item_name][raw_value]
      add_cf(cf_id, cf_value)
    end
  end
end
