class RedmineController

  def initialize(url, user, password)
    RedmineClient::Base.configure do
      self.site = url
      self.user = user
      self.password = password
    end
  end
  # caution: there is a posibility ID is not the last.
  def get_last_im_alert_id(defect_tracker, cf_name)
    last_issue = 
      RedmineClient::Issue.find(:first,
                                :params => {:tracker_id => defect_tracker})
    last_issue.custom_fields.each do |cf|
      return cf.value if cf.name == cf_name
    end
    raise "not found #{cf_name} in ticket id = #{last_issue.id}"
  end

end
