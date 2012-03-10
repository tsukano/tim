require 'thread'
class SaveThreadIssue
  attr_accessor :save_issue_q
  attr_accessor :thread_num
  attr_accessor :group
  def new(thread_num)
    self.save_issue_q = Queue.new
    self.thread_num = thread_num
    self.group = ThreadGroup.new
  end
  def start
    self.thread_num.times do |thread_index|
      self.group.add Thread.start(thread_index) do |index|
        loop do
          issue = save_issue_q.pop
          if issue.save
            $logger.info "[SUCCESS] have saved issue id = #{issue.id}"
          else
            $logger.info "[FAILURE] can't save issue."
            $logger.info issue.errors, issue.errors.full_messages if issue.errors != nil
          end
          #$logger.info "now commented saving"
        end
      end
    end
  end
  def wait_until_stopping
    while is_all_stop == false
    end
  end

  private
  def is_all_stop
    return self.group.list.map {|t| t.stop?}.uniq == [true]
  end
end
