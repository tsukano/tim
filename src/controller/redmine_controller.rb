require "rubygems"
require "redmine_client"

class RedmineController

  CONVERT_CF_NAME = lambda {|cf_id| 'cf_' + cf_id.to_s}
  NO_RECOVER = 'none'

  DESCRIPTION_LINE = "\r\n\r\n---\r\n\r\n"

  def initialize(conf)
    RedmineClient::Base.configure do
      self.site = conf["url"]
      self.user = conf["user"]
      self.password = conf["password"]
    end
  end

  # TODO: performance
  # for improving performance, before running this method, 
  # should prepare all issue(same trigger id)
  # So ,this method dont have to access api.
  def have_registered?(im_alert_id_value, cf_id_alert_or_recovered)
    cf_name_for_param = CONVERT_CF_NAME.call(cf_id_alert_or_recovered)
    issue = RedmineClient::Issue.find(:first,
                                      :params => {cf_name_for_param => 
                                                    im_alert_id_value })
    return issue != nil
  end
  
  def get_defected_ticket(defect_tracker_id, cf_id_value, avoid_issue_id_list, order_id, order_value)
    params = {:tracker_id => defect_tracker_id.to_i}
    cf_id_value.each do |id, value|
      params.store(CONVERT_CF_NAME.call(id), value)
    end
    issue_list = RedmineClient::Issue.find(:all, :params => params)
    issue_list = issue_list.select do |issue|
      !(avoid_issue_id_list.include?(issue.id))
    end
    # sort desc
    issue_list.sort! do |issue_a, issue_b|
      (issue_b.custom_fields.select{|cf| cf.id == order_id})[0].value.to_i -
      (issue_a.custom_fields.select{|cf| cf.id == order_id})[0].value.to_i
    end
    issue_list.each do |issue|
      next unless issue_is_old(issue.custom_fields, order_id, order_value)
      return issue
    end
    return nil
  end
  
  def new_ticket(subject, body, project_id, tracker_id, cf_values)
    return RedmineClient::Issue.new(:subject             => subject,
                                    :description         => body,
                                    :project_id          => project_id,
                                    :tracker_id          => tracker_id,
                                    :custom_field_values => cf_values)
  end

  def modify_cf(issue, cf_updated)
    issue.custom_fields.each do |cf|
      next if cf_updated[cf.id] == nil
      cf.value = cf_updated[cf.id]
    end
  end

  def add_description(issue, body_str)
    issue.description += DESCRIPTION_LINE
    issue.description += body_str
  end

  private

  def issue_is_old(issue_cf, order_id, order_value)
    issue_cf.each do |cf|
      if cf.id == order_id
        if cf.value.to_i < order_value.to_i
          $logger.info( "Issue order : #{cf.value.to_s}" + " < " + 
                        "Mail order : #{order_value.to_s}")
          return true
        end
      end
    end
    return false
  end
end
