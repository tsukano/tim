# -*- coding: utf-8 -*-
require 'rubygems'
require 'ruby-debug'

ex_path = File.expand_path(File.dirname(__FILE__))
require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/im_config'
require ex_path + '/lib/im_log'
require ex_path + '/lib/report'
require ex_path + '/lib/redmine_controller'
require ex_path + '/lib/zabbix_controller'
require ex_path + '/lib/save_issue_thread'

CONF_FILE = ex_path + '/../config.yaml'

class RedmineSyncer

  def initialize
    @repo = Report.new

    @conf = ImConfig.new(CONF_FILE)
    $logger = ImLog.logger(@conf.log_stdout?, @conf.log_file?,@conf.log_filepath)
    $logger.info "logger is ready"
    @redmine = RedmineController.new(@conf.get("hosts.redmine"))
    @mail_session = MailSession.new(@conf.get("hosts.mail")) if @conf.mail?
    @zabbix = ZabbixController.new(@conf.get('hosts.zabbix')) if @conf.zabbix_api?
    @thread = SaveIssueThread.new(@conf.thread_num, @conf.thread_timeout)
  end

  def main
    $logger.info "===== Start main method"
    if @conf.mail?
      tmail_list = @mail_session.get_recent_list(@conf.interval,
                                                 @conf.subject_header)
      @mail_session.finalize
    elsif @conf.zabbix_api?
      tmail_list = @zabbix.get_recent_alert(@conf.interval).map do |alert|
        MailSession.convert_faked_tmail(alert["alertid"], 
                                        alert["subject"],
                                        alert["message"])
      end
    end
    if tmail_list.size == 0
      $logger.info "recent Alert(mail/api) is nothing"
      return
    end

    @repo.set_count("TMail Candidate", tmail_list.size)
    @thread.start
    $logger.info "===== Start thread for saving issue"
    updating_target = Hash.new

    tmail_list.each do |t_mail|
      im_alert_id_value = t_mail[MailSession::TMAIL_IM_ALERT_ID].to_s
      $logger.info " * Alert unique id =#{im_alert_id_value}"
      m_body = MailParser.new(t_mail.body, 
                              @conf.separator, 
                              @conf.cf_mapping,
                              @conf.null_value,
                              @conf.zabbix?)
      if(@conf.zabbix? &&
         m_body.recovered_zabbix?(ImConfig::LIST_ZABI_RECOVER, @conf.cf_mapping))

        $logger.info " - candidate for updating ticket"
        next if @redmine.have_registered?(im_alert_id_value, @conf.im_recovered_id)
        $logger.info " - check done. have not updated."
        updating_target.store(im_alert_id_value, m_body)
        $logger.info " >>> (set updating target)"
      else
        $logger.info " - candidate for creating ticket"
        next if @redmine.have_registered?(im_alert_id_value, @conf.im_alert_id)
        $logger.info " - check done. have not registered."
        m_body.add_cf(@conf.im_alert_id, im_alert_id_value)
        
        # TODO:delete no recover
        m_body.add_cf(@conf.im_recovered_id, RedmineController::NO_RECOVER)
        # no recover flag is for searching defect issue.(in next method update issue)
        # Because API can't find cf='' in now version(0.9)
        issue = @redmine.new_ticket(t_mail.subject,
                                    t_mail.body,
                                    @conf.im_prj_id,
                                    @conf.tracker_id,
                                    m_body.cf_id_values)
        @thread.enq issue
        $logger.info " >>> set queue for saving"
      end
    end
    @repo.set_count('Ticket - Create',@thread.count_sum)
    @thread.wait_for_finishing
    $logger.info "have finished creating ticket"
    if updating_target.size > 0
      update_ticket(updating_target) 
      @thread.wait_for_finishing
      $logger.info "have finished updating ticket"
      @repo.set_count('Ticket - Update',
                      @thread.count_sum - @repo.get_count('Ticket - Create'))
      @repo.set_count('Ticket - ALL', @thread.count_sum)
    end
    $logger.info "===== have finished"
    $logger.info @repo.report
  end

  private

  def update_ticket(id_and_body_list)
    $logger.info "===== Start to update ticket for recovery mail"
    avoid_issue_id_list = Array.new

    id_and_body_list.each do |im_alert_id_value, m_body|
      $logger.info " * Alert unique id =#{im_alert_id_value}"
      cf_conditions = m_body.get_part_of_cf(ImConfig::LIST_SAME_TRIGGER,
                                            @conf.cf_mapping["cf_id"])
      next unless cf_conditions.size == ImConfig::LIST_SAME_TRIGGER.size
      cf_conditions.store(@conf.im_recovered_id ,
                          RedmineController::NO_RECOVER)
      $logger.info " - have set conditions for finding defected ticket."
      issue = @redmine.get_defected_ticket(@conf.tracker_id,
                                           cf_conditions,
                                           avoid_issue_id_list,
                                           @conf.im_alert_id,
                                           im_alert_id_value)
      next if issue == nil
      $logger.info " - target issue id =#{issue.id}"
      # for avoiding conflict to save each threads
      avoid_issue_id_list.push issue.id

      cf_updated = m_body.get_part_of_cf(ImConfig::LIST_ZABI_RECOVER,
                                         @conf.cf_mapping["cf_id"])
      cf_updated.store(@conf.im_recovered_id ,im_alert_id_value)

      @redmine.modify_cf(issue, cf_updated)
      @thread.enq issue
      $logger.info " >>> set queue for saving"
    end
  end
end

RedmineSyncer.new.main

