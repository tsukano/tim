class MailParser

  ZABI_TRIGGER_VALUE_NORMAL = 0
  attr_accessor :raw_body
  attr_accessor :cf_values

  def initialize(body, cf_mapping_id, cf_mapping_value)
    self.raw_body = Hash.new
    parse(body)
    self.cf_values = Hash.new
    cf_convert(cf_mapping_id, cf_mapping_value)
  end

  # only zabbix
  def recovered?()
    self.raw_body['TRIGGER.VALUE'] == ZABI_TRIGGER_VALUE_NORMAL
  end

  def get_cf(item_name)
    return self.cf_values[item_name]
  end

  def add_cf(cf_id, cf_value)
    self.cf_values.store(cf_id, cf_value)
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

  def cf_convert(conf_id, conf_value)
    self.raw_body.each do |raw_key, raw_value|
      # TODO: item name may not be same api item name. like japanese.
      # rakuda
      config_item_name = raw_key.downcase.gsub(/[\-\.\s]/, '_') 
      cf_id = conf_id[config_item_name]
      next if cf_id == nil
      cf_value = conf_value[config_item_name] == nil ? raw_value :
                                                       conf_value[config_item_name][raw_value]
      self.cf_values.store(cf_id, cf_value)
    end
  end
end
