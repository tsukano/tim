require 'rubygems'
require 'json'
require 'zabbixapi'

class ZabbixController

  def initialize(conf)
    @zabi = Zabbix::ZabbixApi.new(conf["url"], 
                                  conf["user"], 
                                  conf["password"])
  end
  def get_recent_alert(interval_before_now)
    time_from = Time.now - interval_before_now
    return @zabi.do_request({:method => 'alert.get',
                             :params => {:output    => 'extend',
                                         :time_from => time_from.to_i},
                             :auth   => @zabi.auth })
  end
end
