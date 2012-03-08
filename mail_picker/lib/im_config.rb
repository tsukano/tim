require 'yaml'

class ImConfig

  attr_accessor :conf
  ALERT_TYPE_MAIL = "mail"
  ALERT_TYPE_ZABBIX_API = "zabbix_api"

  MONITORING_SYSTEM_ZABBIX = "zabbix"
  MONITORING_SYSTEM_HINEMOS = 'hinemos'

  LIST_ZABI_RECOVER = ["trigger_value",
                       "trigger_status",
                       "status"]
  LIST_SAME_TRIGGER = ["hostname",
                       "trigger_id"]

  def initialize(conf_file)
    self.conf = YAML.load_file(conf_file)
    raise 'no conf item' if self.conf.size == 0
  end

  # get value from conf instance
  # using period separator, you can get child value
  def get(conf_item)
    item_value = nil
    conf_item.split('.').each do |item|
      if item_value == nil
        item_value = self.conf[item]
      else
        item_value = item_value[item]
      end
      raise "<#{conf_item}> no such item" if item_value == nil
    end
    return item_value
  end

  def zabbix?
    self.conf["monitoring_system"] == MONITORING_SYSTEM_ZABBIX
  end
  def hinemos?
    self.conf["monitoring_system"] == MONITORING_SYSTEM_HINEMOS
  end
  def mail?
    self.conf["alert_type"] == ALERT_TYPE_MAIL
  end
  def zabbix_api?
    self.conf["alert_type"] == ALERT_TYPE_ZABBIX_API
  end
  def cf_mapping_id
    get_cf("id")
  end
  def cf_mapping_value
    get_cf("value")
  end

  private
  
  def get_cf(id_or_value)
    return get( "redmine_mapping." + 
                "cf_#{id_or_value}_#{self.conf['monitoring_system']}")
  end
end
