class RedmineController

  CUSTOM_FIELD_HEADER = 'cf_'

  def initialize(url, user, password)
    RedmineClient::Base.configure do
      self.site = url
      self.user = user
      self.password = password
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
  def get_defected_ticket(defect_tracker_id, *cf_id_and_value_list)
    params = {:tracker_id => defect_tracker_id}
    cf_id_and_value_list.each do |id_value|
      params.store(CUSTOM_FIELD_HEADER + id_value.keys[0].to_s, 
                   id_value.values[0])
    end
    return RedmineClient::Issue.find(:first, :params => params)
  end
  def new_ticket(subject, body, project_id, *cf)
    return RedmineClient::Issue.new(:subject             => subject,
                                    :description         => body,
                                    :project_id          => project_id,
                                    :custom_field_values => cf)
  end
  def save(issue)
    issue.save
  end
end
