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
    def initialize(url, frequency, url_block)
      @url = url
      @frequency = frequency
      @time_left = frequency
      @url_block = url_block
    end

    def time_expired?(elapsed_time)
      self.time_left -= elapsed_time
      if self.time_left <= 0
        self.time_left = self.frequency
        return true
      else
        return false
      end
    end

    def url
      if @url_block
        @url_block.call
      else
        @url
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
  def update_every(*args, &block)
    if args.size == 1
      frequency = args.first
      raise ArgumentError.new("block expected") unless block
    elsif args.size == 2
      url, frequence = args
    else
      raise ArgumentError.new("expecting either a frequency and block or a url and a frequency")
    end

    updater = ObjectsFromUpdates.new(url, frequency, block)
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
              if response.status_code.to_i == 200
                @application.update_every_succeeded
                #puts "response.json = #{response.json}"
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

  def process_queue_entry(object_to_update)
    object_to_update.state = :updating
    object = object_to_update.object
   
    if @application.respond_to?(:url_for_object)
      root_url = @application.url_for_object(object)
    else
      root_url = @application.url_for_object_and_action(object, object_to_update.action)
    end
    root_url_with_id = "#{root_url}/#{object_to_update.object.id}"
    object_key = @application.object_key_for_object(object)

    payload = {object_key => object.attributes}
    headers = {"Accept" => 'application/json', "content-Type" => 'application/json'}
    case object_to_update.action 
    when :insert
      puts "POSTING(#{root_url}): object=#{object.attributes}"
      HTTP.post(root_url, payload: payload, headers: headers) do |response| 
        puts "POST RESPONSE(#{root_url}): #{response.body}"
        if handle_response(response)
          object.update_id(response.json[object_key]['id'])
        end
      end
    when :update
      puts "PUT(#{root_url_with_id}): object=#{object.attributes}"
      HTTP.put(root_url_with_id, payload: payload, headers: headers) do |response| 
        handle_response(response)
      end
    when :delete
      puts "DELETE(#{root_url_with_id})"
      HTTP.delete(root_url_with_id, headers: headers) do |response| 
        handle_response(response)
      end
    end
  end

  def handle_response(response)
    puts "response.status = #{response.status_code}"
    if response.status_code.to_i >= 200 && response.status_code.to_i <= 299
      puts "OK: response #{response}"
      @object_queue.shift
      puts "OK: after remove head, process queue: #{@object_queue.size}"
      process_queue if @object_queue.size > 0
      return true
    else
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
      return false
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


