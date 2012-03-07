# -*- coding: utf-8 -*-

require 'net/pop'
require 'rubygems'
require 'nkf'
require 'yaml'
require 'rexchange'
require 'thread'
require 'time' 
require 'tmail'
require 'redmine_client'

ex_path = File.expand_path(File.dirname(__FILE__))

require ex_path + '/mail/mail_parser'
require ex_path + '/mail/mail_session'
require ex_path + '/lib/im_config'
require ex_path + '/lib/redmine_controller'

CONF_FILE = ex_path + '/../config.yaml'

MAIL_ENCODER = Proc.new{|string| NKF.nkf('-w',string)}
MAIL_SEPARATOR = ":：=＝"

REG_SIGN = {:year   => '%Y',
            :month  => '%m', 
            :day    => '%d', 
            :hour   => '%H', 
            :minute => '%M', 
            :second => '%S'}

class MailPicker

  def initialize
    @conf = ImConfig.new(CONF_FILE)
    @redmine = RedmineController.new(@conf.get("hosts.redmine.url"),
                                     @conf.get("hosts.redmine.user"),
                                     @conf.get("hosts.redmine.password"))
    if @conf.mail? 
      @mail_session = MailSession.new(@conf.get("hosts.mail.address"), 
                                      @conf.get("hosts.mail.port"),
                                      @conf.get("hosts.mail.user"), 
                                      @conf.get("hosts.mail.password"))
    end 
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
      p 'tmail id =' + t_mail[MailSession::TMAIL_IM_ALERT_ID].to_s
      next unless MAIL_ENCODER.call(t_mail.subject).start_with?(
                                @conf.get("mail_condition.subject_header"))

      p 'checked conditions'
      next if @redmine.have_registered?(t_mail[MailSession::TMAIL_IM_ALERT_ID],
                                       @conf.get("redmine_mapping.cf_id.im_alert_id"),
                                       @conf.get("redmine_mapping.cf_id.im_recovered_alert_id"))
      p 'have not registered'

      m_body = MailParser.new(MAIL_ENCODER.call(t_mail.body),
                              @conf.cf_mapping_id,
                              @conf.cf_mapping_value)

      if @conf.zabbix? && m_body.recovered?
        # update ticket
        cf_id_and_value_list = ["hostname","trigger_id"].map do |item|
          {@conf.get("redmine_mapping.cf_id_zabbix.#{item}") => m_body.get_cf(item)}
        end
        issue = @redmine.get_defected_ticket(@conf.get("redmine_mapping.defect_tracker_id"),
                                            cf_id_and_value_list)
        
        # TODO:
        # set recoverd id / trigger value / trigger name
        #redmine.set_custom_field(issue, )
      # new ticket
      else
        m_body.add_cf(@conf.get("redmine_mapping.cf_id.im_alert_id"),
                      t_mail[MailSession::TMAIL_IM_ALERT_ID])
        issue = @redmine.new_ticket(MAIL_ENCODER.call(t_mail.subject),
                                    MAIL_ENCODER.call(t_mail.body),
                                   @conf.get("redmine_mapping.im_project_id"),
                                   m_body.cf_values)
      end
      @redmine.save(issue)
      p "save issue id = #{issue.id}"
    end
	end
end

MailPicker.new.main

