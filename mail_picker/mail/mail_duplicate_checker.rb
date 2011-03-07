#
# check if the mail has created
#
class MailDuplicateChecker

  attr_accessor :unique_id_list

  def initialize
    begin
      ids_file = File.open(IDS_FILE)
    rescue
      $hinemosTracLog.puts_message("Failure to open the mail id file (#{IDS_FILE}) that has finished creating the ticket.")
      return
    else
      $hinemosTracLog.puts_message("Success to open the mail id file (#{IDS_FILE}).")
    end

    @unique_id_list = Array.new
    while line = ids_file.gets do
      @unique_id_list.push(line.chomp) unless line.empty?
    end
    ids_file.close
  end

#
# check if ticket has created
#
  def has_created_ticket?(unique_id)
    unique_id_list.include?(unique_id)
  end


#
# write the unique id of the mail that has created ticket in the file
#
  def write_id(unique_id)
    begin
      ids_file = open(IDS_FILE, "a")
      ids_file.puts(unique_id)
      ids_file.close
    rescue
      return false
    end
    unique_id_list.push(unique_id)
    return true
  end

end
