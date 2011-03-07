#
# check if the mail has created
#
class MailDuplicateChecker

  attr_accessor :message_id_list

  def initialize
    begin
      ids_file = File.open(IDS_FILE)
    rescue
      $hinemosTracLog.puts_message("Failure to open the mail id file (#{IDS_FILE}) that has finished creating the ticket.")
      return
    else
      $hinemosTracLog.puts_message("Success to open the mail id file (#{IDS_FILE}).")
    end

    @message_id_list = Array.new
    while line = ids_file.gets do
      @message_id_list.push(line.chomp) unless line.empty?
    end
    ids_file.close
  end

#
# check if ticket has created
#
  def has_created_ticket?(message_id)
    message_id_list.include?(message_id)
  end


#
# write the unique id of the mail that has created ticket in the file
#
  def write_id(message_id)
    begin
      ids_file = open(IDS_FILE, "a")
      ids_file.puts(message_id)
      ids_file.close
    rescue
      return false
    end
    message_id_list.push(message_id)
    return true
  end

end
