class Object
  def capture_exception
    begin
      yield
    rescue Exception => e
      puts "Exception: #{e}"
      e.backtrace[0..10].each do |bt|
        puts bt
      end
    end      
  end
end

