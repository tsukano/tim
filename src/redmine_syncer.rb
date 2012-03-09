# -*- coding: utf-8 -*-
require 'thread'
require 'rubygems'
require 'ruby-debug'

ex_path = File.expand_path(File.dirname(__FILE__))
require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/im_config'
require ex_path + '/lib/redmine_controller'
require ex_path + '/lib/zabbix_controller'

CONF_FILE = ex_path + '/../config.yaml'

class RedmineSyncer

  def initialize
    @conf = ImConfig.new(CONF_FILE)
    @redmine = RedmineController.new(@conf.get("hosts.redmine"))
    @mail_session = MailSession.new(@conf.get("hosts.mail")) if @conf.mail?
    @zabbix = ZabbixController.new(@conf.get('hosts.zabbix')) if @conf.zabbix_api?
    @tmail_list = Array.new
    @issue_list = Array.new
  end

  def main
    if @conf.mail?
      @tmail_list = @mail_session.get_recent_list(@conf.interval,
                                                  @conf.subject_header)
      @mail_session.finalize
    elsif @conf.zabbix_api?
      @tmail_list = @zabbix.get_recent_alert(@conf.interval).map do |alert|
        MailSession.convert_faked_tmail(alert["message"], alert["alertid"])
      end
    end

    @tmail_list.each do |t_mail|
      im_alert_id_value = t_mail[MailSession::TMAIL_IM_ALERT_ID].to_s
      p "Alert(from Mail/API) unique id =#{im_alert_id_value}"
      m_body = MailParser.new(t_mail.body, 
                              @conf.separator, 
                              @conf.cf_mapping,
                              @conf.zabbix?)
      if @conf.zabbix? && 
           m_body.recovered_zabbix?(ImConfig::LIST_ZABI_RECOVER, @conf.cf_mapping)
        p " - candidate for updating ticket"
        next if @redmine.have_registered?(im_alert_id_value, @conf.im_recovered_id)
        p " - check done. have not updated."

        cf_conditions = Hash.new
        ImConfig::LIST_SAME_TRIGGER.each do |item|
          next if m_body.get_cf(item) == nil
          cf_conditions.store(@conf.get("redmine_mapping.zabbix.cf_id.#{item}"),
                              m_body.get_cf(item))
        end
        issue = @redmine.get_defected_ticket(@conf.defect_tracker_id,
                                             cf_conditions)
        next if issue == nil
        p " - target issue id =#{issue.id}"

        cf_updated = {@conf.im_recovered_id => im_alert_id_value}
        ImConfig::LIST_ZABI_RECOVER.each do |conf_name|
          cf_id = @conf.get("redmine_mapping.zabbix.cf_id." + conf_name)
          next if m_body.get_cf(cf_id) == nil
          cf_updated.store(cf_id, m_body.get_cf(cf_id))
        end
        @redmine.modify_cf(issue, cf_updated)
      else
        p " - candidate for creating ticket"

        next if @redmine.have_registered?(im_alert_id_value, @conf.im_alert_id)
        p " - check done. have not registered."

        m_body.add_cf(@conf.im_alert_id, im_alert_id_value)
        issue = @redmine.new_ticket(t_mail.subject,
                                    t_mail.body,
                                    @conf.im_prj_id,
                                    @conf.defect_tracker_id,
                                    m_body.cf_values)
      end
      @issue_list.push issue
      p " >>> set list for saving"
    end
    @issue_list.each do |issue|
      p "will save issue title = #{issue.subject}"
      if @redmine.save(issue)
        p " >>> [SUCCESS] have saved issue id = #{issue.id}"
      else
        p " >>> [FAILURE] can't save issue."
        p issue.errors, issue.errors.full_messages if issue.errors != nil
      end
      #p "now commented saving"
    end
  end
end

RedmineSyncer.new.main

