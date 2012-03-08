require "rubygems"
require "redmine_client"

class RedmineController

  CUSTOM_FIELD_HEADER = 'cf_'

  def initialize(conf)
    RedmineClient::Base.configure do
      self.site = conf["url"]
      self.user = conf["user"]
      self.password = conf["password"]
    end
  end

  def have_registered?(im_alert_id, cf_id_alert, cf_id_recovered)
    [cf_id_alert, cf_id_recovered].each do |cf_id|
      issue = RedmineClient::Issue.
                find(:first,
                     :params =>
                       {CUSTOM_FIELD_HEADER + cf_id.to_s => im_alert_id })
      return true if issue != nil
    end
    return false
  end
  
  def get_defected_ticket(defect_tracker_id, cf_id_value)
    params = {:tracker_id => defect_tracker_id}
    cf_id_value.each do |id, value|
      params.store(CUSTOM_FIELD_HEADER + id.to_s, value)
    end
    return RedmineClient::Issue.find(:first, :params => params)
  end
  
  def new_ticket(subject, body, project_id, cf_values)
    return RedmineClient::Issue.new(:subject             => subject,
                                    :description         => body,
                                    :project_id          => project_id,
                                    :custom_field_values => cf_values)
  end

  def modify_cf(issue, cf_updated)
    issue.custom_fields.each do |cf|
      next if cf_updated[cf.id] == nil
      cf.value = cf_updated[cf.id]
    end
  end
  
  def save(issue)
    issue.save
  end
end
