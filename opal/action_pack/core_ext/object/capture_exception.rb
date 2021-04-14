class Object
  include SemanticLogger::Loggable
  def capture_exception
    begin
      yield
    rescue Exception => e
      logger.error "Exception: #{e}", tags: [:exception]
      e.backtrace[0..10].each do |bt|
        logger.error bt, tags: [:exception, :backtrace]
      end
    end      
  end
end

