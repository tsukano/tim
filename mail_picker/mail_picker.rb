# -*- coding: utf-8 -*-
require 'nkf'
require 'thread'
require 'rubygems'
require 'ruby-debug'

ex_path = File.expand_path(File.dirname(__FILE__))
require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/im_config'
require ex_path + '/lib/redmine_controller'

CONF_FILE = ex_path + '/../config.yaml'

MAIL_ENCODER = Proc.new{|string| NKF.nkf('-w',string)}
MAIL_SEPARATOR = ":：=＝"

class MailPicker

  def initialize
    @conf = ImConfig.new(CONF_FILE)
    @redmine = RedmineController.new(@conf.get("hosts.redmine"))
    @mail_session = MailSession.new(@conf.get("hosts.mail")) if @conf.mail?
  end

  def main
    tmail_list = Array.new
    if @conf.mail?
      tmail_list = @mail_session.get_recent_tmail_list(
                     @conf.get("interval_sec_before_now_for_checking"))
      @mail_session.finalize
    elsif @conf.zabbix_api?
      # TODO:API 
      # must start configured mail title
    end

    tmail_list.each do |t_mail|
      p "tmail id =#{t_mail[MailSession::TMAIL_IM_ALERT_ID].to_s}"
      next unless MAIL_ENCODER.call(t_mail.subject).start_with?(
                                @conf.get("mail_condition.subject_header"))

      p ' - checked conditions'
      next if @redmine.have_registered?(t_mail[MailSession::TMAIL_IM_ALERT_ID],
                                       @conf.get("redmine_mapping.cf_id.im_alert_id"),
                                       @conf.get("redmine_mapping.cf_id.im_recovered_alert_id"))
      p ' - have not registered'
      p "t_mail body = #{t_mail.body}"

      m_body = MailParser.new(MAIL_ENCODER.call(t_mail.body),
                              @conf.cf_mapping_id,
                              @conf.cf_mapping_value)
      if @conf.hinemos? && m_body.recovered_hinemos?
        next
      elsif @conf.zabbix? && 
            m_body.recovered_zabbix?(ImConfig::LIST_ZABI_RECOVER,
                                     @conf.get("redmine_mapping.cf_id_zabbix"),
                                     @conf.get("redmine_mapping.cf_value_zabbix"))
        p " - will update ticket"
        cf_conditions = Hash.new
        ImConfig::LIST_SAME_TRIGGER.each do |item|
          next if m_body.get_cf(item) == nil
          cf_conditions.store(@conf.get("redmine_mapping.cf_id_zabbix.#{item}"),
                            m_body.get_cf(item))
        end
        issue = @redmine.get_defected_ticket(@conf.get("redmine_mapping.defect_tracker_id"),
                                             cf_conditions)
        next if issue == nil
        p " - target issue id =#{issue.id}"

        cf_updated = {@conf.get("redmine_mapping.cf_id.im_recovered_alert_id") =>
                      t_mail[MailSession::TMAIL_IM_ALERT_ID]}
        ImConfig::LIST_ZABI_RECOVER.each do |conf_name|
          cf_id = @conf.get("redmine_mapping.cf_id_zabbix." + conf_name)
          next if m_body.get_cf(cf_id) == nil
          cf_updated.store(cf_id, m_body.get_cf(cf_id))
        end
        @redmine.modify_cf(issue, cf_updated)
      else
        # TODO: is defect ticket zabi/hihne
        p " - will create ticket"
        m_body.add_cf(@conf.get("redmine_mapping.cf_id.im_alert_id"),
                      t_mail[MailSession::TMAIL_IM_ALERT_ID])
        issue = @redmine.new_ticket(MAIL_ENCODER.call(t_mail.subject),
                                    MAIL_ENCODER.call(t_mail.body),
                                   @conf.get("redmine_mapping.im_project_id"),
                                   m_body.cf_values)
      end
      @redmine.save(issue)
      p " >>> have saved issue id = #{issue.id}"
      #p "now commented saving"
    end
	end
end

MailPicker.new.main

