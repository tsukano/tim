require 'yaml'

class ImConfig

  attr_accessor :conf
  ALERT_TYPE_MAIL = "mail"
  ALERT_TYPE_ZABBIX_API = "zabbix_api"

  MONITORING_SYSTEM_ZABBIX = "zabbix"
  MONITORING_SYSTEM_HINEMOS = 'hinemos'

  LOG_MODE_STDOUT = "stdout"
  LOG_MODE_FILE = "file"

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

  #
  # checker
  #
  def zabbix?
    get("monitoring_system") == MONITORING_SYSTEM_ZABBIX
  end
  def hinemos?
    get("monitoring_system") == MONITORING_SYSTEM_HINEMOS
  end
  def mail?
    get("alert_type") == ALERT_TYPE_MAIL
  end
  def zabbix_api?
    get("alert_type") == ALERT_TYPE_ZABBIX_API
  end
  def log_stdout?
    get("log.mode") == LOG_MODE_STDOUT
  end
  def log_file?
    get("log.mode") == LOG_MODE_FILE
  end
  #
  # getter (general)
  #
  def interval
    return get("interval_sec_before_now_for_checking")
  end
  def separator
    return get("mail.separator_character")
  end
  def subject_header
    return get("mail.subject_header")
  end
  def thread_num
    return get("thread.num")
  end
  def thread_timeout
    return get("thread.timeout_sec_for_waiting_save")
  end
  def log_filepath
    return get("log.filepath")
  end
  #
  # getter (redmine custom field)
  #
  def im_alert_id
    return get('redmine_mapping.cf_id.im_alert_id')
  end
  def im_recovered_id
    return get("redmine_mapping.cf_id.im_recovered_alert_id")
  end
  def cf_mapping
    return get("redmine_mapping.#{get('monitoring_system')}")
  end
  def tracker_id
    return get("redmine_mapping.#{get('monitoring_system')}.tracker_id")
  end
  def null_value
    return get("redmine_mapping.#{get('monitoring_system')}.null_value")
  end
  def im_prj_id
    return get("redmine_mapping.im_project_id")
  end
  def order
    return get("redmine_mapping.zabbix.cf_id.im_order")
  end
end
