class Report

  CRLF = "\r\n"

  def initialize()
    @start_time = Time.now
    @count_name = Array.new
    @count = Array.new
    @report = String.new
  end

  def set_count(name, count)
    @count_name.push name
    @count.push count
  end

  def get_count(name)
    index = @count_name.index(name)
    return @count[index]
  end

  def report
    end_time = Time.now

    add_line "===== REPORTING"
    add_line "* Count"
    @count_name.each_with_index do |name, i|
      add_line " - #{name} : #{@count[i]} "
    end
    add_line " * Time"
    add_line " - Start : #{@start_time}"
    add_line " - End   : #{end_time}"
    add_line " >>> #{(end_time - @start_time).to_i} seconds"
    return @report
  end

  private

  def add_line(line)
    @report += line
    @report += CRLF
  end
end
