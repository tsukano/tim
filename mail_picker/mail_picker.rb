# -*- coding: utf-8 -*-
require 'thread'
require 'rubygems'
require 'ruby-debug'

ex_path = File.expand_path(File.dirname(__FILE__))
require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/im_config'
require ex_path + '/lib/redmine_controller'

CONF_FILE = ex_path + '/../config.yaml'

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
      tmail_list = @mail_session.get_recent_tmail_list(@conf.interval,
                                                       @conf.subject_header)
      @mail_session.finalize
    elsif @conf.zabbix_api?
      # TODO:API 
    end

    tmail_list.each do |t_mail|
      p "tmail id =#{t_mail[MailSession::TMAIL_IM_ALERT_ID].to_s}"
      next if @redmine.have_registered?(t_mail[MailSession::TMAIL_IM_ALERT_ID],
                                       @conf.im_alert_id,
                                       @conf.im_recovered_id)
      p " - have not registered.t_mail body is", t_mail.body

      m_body = MailParser.new(t_mail.body, @conf.cf_mapping)
      if @conf.hinemos? && m_body.recovered_hinemos?
        next
      elsif @conf.zabbix? && 
            m_body.recovered_zabbix?(ImConfig::LIST_ZABI_RECOVER,
                                     @conf.get("redmine_mapping.zabbix"))
        p " - will update ticket"
        cf_conditions = Hash.new
        ImConfig::LIST_SAME_TRIGGER.each do |item|
          next if m_body.get_cf(item) == nil
          cf_conditions.store(@conf.get("redmine_mapping.zabbix.cf_id.#{item}"),
                              m_body.get_cf(item))
        end
        issue = @redmine.get_defected_ticket(@conf.get("redmine_mapping.defect_tracker_id"),
                                             cf_conditions)
        next if issue == nil
        p " - target issue id =#{issue.id}"

        cf_updated = {@conf.im_recovered_id =>
                      t_mail[MailSession::TMAIL_IM_ALERT_ID]}
        ImConfig::LIST_ZABI_RECOVER.each do |conf_name|
          cf_id = @conf.get("redmine_mapping.zabbix.cf_id." + conf_name)
          next if m_body.get_cf(cf_id) == nil
          cf_updated.store(cf_id, m_body.get_cf(cf_id))
        end
        @redmine.modify_cf(issue, cf_updated)
      else
        # TODO: is defect ticket zabi/hihne
        p " - will create ticket"
        m_body.add_cf(@conf.im_alert_id,
                      t_mail[MailSession::TMAIL_IM_ALERT_ID])
        issue = @redmine.new_ticket(t_mail.subject,
                                    t_mail.body,
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

