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
                       {CUSTOM_FIELD_HEADER + cf_id => im_alert_id })
      return true if issue != nil
    end
    return false
  end
end
