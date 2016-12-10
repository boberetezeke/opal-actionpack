module Kernel
  def every interval, &block
    callback = `function(){ #{block.call}; }`
    `setInterval(callback, #{interval * 1000})`
  end

  def after delay, &block
    callback = `function(){ #{block.call}; }`
    `setTimeout(callback, #{delay * 1000})`
  end
end

class Numeric
  def seconds
    self
  end
end


class ActionSyncer
  UPDATE_FREQUENCY = 1000

  class ObjectToUpdate
    attr_accessor :action, :object, :state, :retry_count
    def initialize(action, object, state)
      @action = action
      @object = object
      @state = state
      @retry_count = 0
    end

    def reset
      @retry_count = 0
      @state = :idle
    end
  end

  class ObjectsFromUpdates
    attr_accessor :frequency, :time_left
    def initialize(frequency, url_block)
      @frequency = frequency
      @time_left = frequency
      @url_block = url_block
    end
    
    def url
      @url_block.call
    end

    def time_expired?(elapsed_time)
      @time_left -= elapsed_time
      if @time_left <= 0
        @time_left = @frequency
        return true
      else
        return false
      end
    end
  end
  
  class RemoteSaver
    attr_reader :url, :object, :object_key, :action
    
    def initialize(url, object, object_key, action)
      @url = url
      @object = object
      @object_key = object_key
      @action = action
      
      puts "url = #{url}"
      puts "object = #{object}"
      puts "object_key = #{object_key}"
      puts "action = #{@action}"
    end
    
    def headers
      headers = {"Accept" => 'application/json', "content-Type" => 'application/json'}
    end
    
    def payload
      {object_key => @object.attributes}
    end
    
    def save
      puts "action = #{action}, @action = #{@action}"
      case @action
      when :insert
        puts "POST to (#{url}): object=#{object.attributes}"
        HTTP.post(url, payload: payload, headers: headers).when do |response|
          puts "response.json = #{response.json}"
          puts "object_key = #{object_key}"
          puts "object = [#{object.object_id}]:#{object}"
          new_id = response.json[object_key]['id']
          puts "new_id = #{new_id}"
          object.update_id(new_id)
          
          puts "object (after) = [#{object.object_id}]:#{object}"
          Promise.new.resolve(response)
        end.error do |response|
          Promise.new.reject(response)
        end
      when :update
        puts "PUT to (#{url}): object=#{object.attributes}, payload: #{payload}"
        HTTP.put(url, payload: payload, headers: headers)
      when :delete
        puts "ACTION(delete to (#{url})"
        HTTP.delete(url, headers: headers)
      else
        raise "Unknown action in save: #{action.inspect}"
      end
    end
  end

  # scenarios
  #
  # 1 - update_object(1), update_object(1)
  #    replace first with second 
  # 2 - update_object(1, saving), update_object(1)
  #    finish save of first and then save object
  # 3 - insert_object(t-1), update_object(t-1)
  #    update contents of insert with update
  # 4 - insert object(t-1,saving), update_object(t-1)
  #    finish save, update id's in list and stored objects with new id
  # 5 - update_object(1), delete_object(1)
  #    replace update with delete
  # 6 - insert_object(1), delete_object(1)
  #    remove both
  # 7 - update_object(1, saving), delete_object(1)
  #    leave in list
  #
  # NOTE: on delete, what about references to objects?
  # NOTE: how to do cascading delete

  attr_reader :object_queue

  INITIALIZE_DEFAULTS = {max_retries: 5}
  def initialize(application, options={})
    options = INITIALIZE_DEFAULTS.merge(options)
    @application = application
    @object_queue = []
    @update_queue = []
    @max_retries = options[:max_retries]

    every UPDATE_FREQUENCY / 1000 do
      process_updates
    end
  end

  def on_change(action, object)
    object_to_update = ObjectToUpdate.new(action, object, :idle)

    objects_queued_to_update = @object_queue.select{|ots| ots.object.id == object.id}
    if objects_queued_to_update.empty?
      @object_queue.push(object_to_update)
    else
      first_in_queue = objects_queued_to_update.first

      # UPDATE
      if object_to_update.action == :update
        on_update_action(object_to_update, first_in_queue)

      # INSERT
      elsif object_to_save.action == :insert

      # DELETE
      else
        on_delete_action(object_to_update, first_in_queue)
      end
    end

    process_queue
  end

  def retry_on_change
    object_to_update = @object_queue.first
    if object_to_update
      object_to_update.reset

      process_queue
    end
  end

  #
  # do a HTTP GET operation from the supplied path every frequency milliseconds
  # 
  # when the get succeeds, save the objects locally
  #
  def update_every(frequency, url_block)
    updater = ObjectsFromUpdates.new(frequency, url_block)
    @update_queue.push(updater)
    updater
  end

  def stop_updating(updater)
    @update_queue.delete(updater)
  end

  private

  def process_updates
    puts "in process_updates"
    capture_exception do
      @update_queue.each do |updater|
        if updater.time_expired?(UPDATE_FREQUENCY)
          begin
            headers = {"Accept" => 'application/json', "content-Type" => 'application/json'}

            # puts "GET(#{updater.url})"
            #`var d = new Date(); console.log("time= " + d.getSeconds() + ":" + d.getMilliseconds());`
            HTTP.get(updater.url, headers: headers) do |response| 
              #puts "GET(#{updater.url}) got response"
              #`var d = new Date(); console.log("time= " + d.getSeconds() + ":" + d.getMilliseconds());`
              if response.status_code.to_i >= 200 && response.status_code.to_i <= 299
                @application.update_every_succeeded
                puts "response.json = #{response.json}"
                response.json.each do |object_json|
                  @application.create_or_update_object_from_object_key_and_attributes(object_json.keys.first, object_json.values.first)
                end 
              else
                puts "ERROR: status code: #{response.status_code}"
                @application.update_every_failed
              end
              # puts "GET(#{updater.url}) processed response"
              #`var d = new Date(); console.log("time= " + d.getSeconds() + ":" + d.getMilliseconds());`
            end
            #puts "GET done"
          rescue Exception => e
            puts "Exception: #{e}"
            @application.update_every_failed
            raise e
          end
        end
      end
    end
  end

  def process_queue
    # puts "Updater#process_queue: #{@object_queue.size}"
    return if @object_queue.empty? || @object_queue.first.state != :idle

    process_queue_entry(@object_queue.first)
  end


  def object_url(action, object)
    if @application.respond_to?(:url_for_object)
      root_url = @application.url_for_object(object)
    else
      root_url = @application.url_for_object_and_action(object, action)
    end
    if action != :insert
      return "#{root_url}/#{object.id}"
    else
      return root_url
    end
  end
    
  def process_queue_entry(object_to_update)
    RemoteSaver.new(
      object_url(object_to_update.action, object_to_update.object),
      object_to_update.object, 
      @application.object_key_for_object(@object), 
      object_to_update.action
    ).save.when do |response|
      handle_ok_response(response)
    end.error do
      handle_error_response(response)
    end
  end

  def handle_ok_response(response)
    puts "OK: response #{response}"
    @object_queue.shift
    puts "OK: after remove head, process queue: #{@object_queue.size}"
    process_queue if @object_queue.size > 0
  end
  
  def handle_error_response(response)
    puts "ERROR: response #{response}"
    object_to_update = @object_queue.first
    object_to_update.retry_count += 1
    if object_to_update.retry_count >= @max_retries
      puts "NO MORE TRIES: #{object_to_update.retry_count} > #{@max_retries}"
      @application.retry_count_hit
    else
      puts "RETRY # #{object_to_update.retry_count} in #{object_to_update.retry_count} seconds"
      after object_to_update.retry_count.seconds do
        object_to_update.state = :idle
        process_queue_entry(object_to_update)
      end
    end
  end

  def on_insert_action(object_to_update, first_in_queue)
    # there shouldn't be anything in here
    raise "insert with objects already found in queue: #{objects_queued_to_save}"
  end

  def on_update_action(object_to_update, first_in_queue)
    if first_in_queue.action == :update || first_in_queue.action == :insert
      if first_in_queue.state == :idle
        # replace it
        first_in_queue.object = object
      else
        # queue it
        @object_queue.push(object_to_update)
      end
    else
      # throw it away
    end
  end

  def on_delete_action(object_to_update, first_in_queue)
    if first_in_queue.action == :insert || first_in_queue.action == :update
      if first_in_queue.state == :idle
        # remove it from the queue
        @object_queue.delete_if do |otu| 
          otu.object.id == object.id && 
          (otu.action == :insert || otu.action == :delete)
        end
      else
        # queue it
        @object_queue.push(object_to_update)
      end
    # its a DELETE
    else
      # there shouldn't be anything in here
      raise "delete with delete objects already found in queue: #{objects_queued_to_save}"
    end
  end
end


