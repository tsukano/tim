require "rubygems"
require "redmine_client"

class RedmineController

  CONVERT_CF_NAME = lambda {|cf_id| 'cf_' + cf_id.to_s}
  NO_RECOVER = 'none'

  def initialize(conf)
    RedmineClient::Base.configure do
      self.site = conf["url"]
      self.user = conf["user"]
      self.password = conf["password"]
    end
  end

  def have_registered?(im_alert_id_value, cf_id_alert_or_recovered)
    cf_name_for_param = CONVERT_CF_NAME.call(cf_id_alert_or_recovered)
    issue = RedmineClient::Issue.find(:first,
                                      :params => {cf_name_for_param => 
                                                    im_alert_id_value })
    return issue != nil
  end
  
  def get_defected_ticket(defect_tracker_id, cf_id_value, avoid_issue_id_list)
    params = {:tracker_id => defect_tracker_id.to_i}
    cf_id_value.each do |id, value|
      params.store(CONVERT_CF_NAME.call(id), value)
    end
    issue_list = RedmineClient::Issue.find(:all, :params => params)
    debugger
    # TODO:May be cast date!!
    # reverse is for getting most old issue
    issue_list.reverse.each do |issue|
      next if avoid_issue_id_list.include?(issue.id)
      return issue
    end
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
end
