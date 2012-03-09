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
  def im_alert_id
    return get('redmine_mapping.cf_id.im_alert_id')
  end
  def im_recovered_id
    return get("redmine_mapping.cf_id.im_recovered_alert_id")
  end

  def cf_mapping
    return get( "redmine_mapping." + 
                "#{self.conf['monitoring_system']}")
  end
  def interval
    return get("interval_sec_before_now_for_checking")
  end
  def subject_header
    return get("mail_condition.subject_header")
  end
end
