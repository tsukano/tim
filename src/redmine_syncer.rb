# -*- coding: utf-8 -*-
require 'logger'
require 'rubygems'
require 'ruby-debug'

ex_path = File.expand_path(File.dirname(__FILE__))
require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/im_config'
require ex_path + '/lib/redmine_controller'
require ex_path + '/lib/zabbix_controller'
require ex_path + '/lib/save_issue_thread'

CONF_FILE = ex_path + '/../config.yaml'
LOG_FILE  = ex_path + '/../log/im.log'

class RedmineSyncer

  def initialize
    $logger = Logger.new(LOG_FILE)
    @conf = ImConfig.new(CONF_FILE)
    @redmine = RedmineController.new(@conf.get("hosts.redmine"))
    @mail_session = MailSession.new(@conf.get("hosts.mail")) if @conf.mail?
    @zabbix = ZabbixController.new(@conf.get('hosts.zabbix')) if @conf.zabbix_api?
    @thread = SaveIssueThread.new(@conf.thread_num)

    @recovered_target = Hash.new
    @tmail_list = Array.new
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

    SaveIssueThread.start
    @tmail_list.each do |t_mail|
      im_alert_id_value = t_mail[MailSession::TMAIL_IM_ALERT_ID].to_s
      $logger.info "Alert(from Mail/API) unique id =#{im_alert_id_value}"
      m_body = MailParser.new(t_mail.body, 
                              @conf.separator, 
                              @conf.cf_mapping,
                              @conf.zabbix?)
      if(@conf.zabbix? &&
         m_body.recovered_zabbix?(ImConfig::LIST_ZABI_RECOVER, @conf.cf_mapping))

        $logger.info " - candidate for updating ticket"
        next if @redmine.have_registered?(im_alert_id_value, @conf.im_recovered_id)
        $logger.info " - check done. have not updated."
        @recovered_target.store(im_alert_id, m_body)
        # after creating ticket, start updating ticket.
      else
        $logger.info " - candidate for creating ticket"
        next if @redmine.have_registered?(im_alert_id_value, @conf.im_alert_id)
        $logger.info " - check done. have not registered."
        m_body.add_cf(@conf.im_alert_id, im_alert_id_value)
        issue = @redmine.new_ticket(t_mail.subject,
                                    t_mail.body,
                                    @conf.im_prj_id,
                                    @conf.defect_tracker_id,
                                    m_body.cf_values)
        @thread.save_issue_q.enq issue
        $logger.info " >>> set queue for saving"
      end
      @thread.wait_until_stopping
      update_ticket if @recovered_target.size > 0
    end
  end

  private

  def update_ticket
    @recovered_target.each do |im_alert_id, m_body|
      cf_conditions = Hash.new
      ImConfig::LIST_SAME_TRIGGER.each do |item|
        next if m_body.get_cf(item) == nil
        cf_conditions.store(@conf.get("redmine_mapping.zabbix.cf_id.#{item}"),
                            m_body.get_cf(item))
      end
      issue = @redmine.get_defected_ticket(@conf.defect_tracker_id,
                                           cf_conditions)
      next if issue == nil
      $logger.info " - target issue id =#{issue.id}"

      cf_updated = {@conf.im_recovered_id => im_alert_id_value}
      ImConfig::LIST_ZABI_RECOVER.each do |conf_name|
        cf_id = @conf.get("redmine_mapping.zabbix.cf_id." + conf_name)
        next if m_body.get_cf(cf_id) == nil
        cf_updated.store(cf_id, m_body.get_cf(cf_id))
      end
      @redmine.modify_cf(issue, cf_updated)
      @thread.save_issue_q.enq issue
      $logger.info " >>> set queue for saving"
    end
  end
end

RedmineSyncer.new.main

