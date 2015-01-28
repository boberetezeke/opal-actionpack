class Application
  class Action
    attr_reader :name
    def initialize(route, action_type, options)
      @route = route
      @action_type = action_type
      if action_type == :redirect
        @redirect_action = options[:redirect_action]
      else
        @name = options[:name]
        @parts = options[:parts]
      end
    end

    def match(parts, params)
      #puts "Action:match: parts: #{parts.inspect}, name: #{@name}, action_parts: #{@parts.inspect}"
      return false if parts.size != @parts.size
      return true if parts.size == 0

      @parts.each_with_index do |part, index|
        #puts "part = #{part}"
        if part.is_a?(String)
          #puts "part: #{part}, matches: #{parts[index]}"
          return true if /#{part}/.match(parts[index])
        else
          param_key = part.keys.first
          matcher = /(#{part.values.first})/
          if m = matcher.match(parts[index])
            #puts "matcher: #{matcher}, matches #{parts[index]}"
            params[param_key] = m[1]
            return true
          end
        end
      end
      return false
    end

    def match_path(action_name, *args)
      #puts "Action#match_path: action_name = #{action_name}, name = #{@name}, args = #{args.inspect}"
      params = {}
      return [false, params] unless @name.to_s == action_name.to_s

      if args.size > 0 
        if args.last.is_a?(Hash)
          params = args.pop
        end
      end

      if @action_type == :member
        if args.size == 1
          object = args.first
          if object.is_a?(String) || object.is_a?(Numeric)
            object_id = object
          else
            object_id = object.id
          end
          #puts "object_id = #{object_id}, name = #{@name}"
          #
          if @name.to_s == 'show'
            action_root = object_id.to_s
          else
            action_root = "#{object_id}/#{@name}"
          end
          return [action_root, params]
        else
          raise "requires one argument passed to member path"
        end
      else
        if args.size == 0
          #puts "Action#match_path: @name = #{@name}"
          if @name.to_s == 'index'
            # FIXME: need to url encode parameters
            action_root = ""
          else
            action_root = @name
          end
          #puts "action_root = #{action_root}, params=#{params}"
          return [action_root, params]
        else
          raise "argument passed to collection path"
        end
      end
    end

    # 
    # Invoke a controller which will optionally render the associated view
    #
    # params - url params hash
    # options -
    #   :render_view - true if the view is being rendered
    #   :render_only - only render but don't call add_bindings on client controller
    #   :selector - the jquery selector to select the DOM element to render into
    #   :content_for - a hash with keys as the symbol for the content to be rendered (e.g. :footer) 
    #                  and the values as the selector of the DOM element to render into
    #
    def invoke_controller(params, options)
      if @redirect_action
        return @redirect_action.invoke_controller(params, options)
      end

      controller_class_name = "#{@route.name.camelize}Controller"
      controller_class = nil
      begin
        controller_class = Object.const_get(controller_class_name)
      rescue Exception => e
        puts "INFO: client class: #{controller_class_name} doesn't exist"
      end

      return unless controller_class

      controller = controller_class.new(params)
      controller.invoke_action(self)

      if options[:render_view]
        html, content_for_htmls = controller.render_template(content_for: options[:content_for])
        #puts "invoke_controller: html = #{html}"
        Document.find(options[:selector]).html = html
        content_for_htmls.each do |selector, html|
          #puts "invoke_controller: content_for(#{selector}), html = #{html}"
          Document.find(selector).html = html
        end
      end

      controller_client_class_name = "#{@route.name.camelize}ClientController"
      controller_client_class = nil
      controller_action_class = nil

      begin
        controller_client_class = Object.const_get(controller_client_class_name)
      rescue Exception => e
        puts "INFO: client class: #{controller_client_class_name} doesn't exist"
      end

      return unless controller_client_class

      begin
        controller_action_class = controller_client_class.const_get(@name.capitalize)
      rescue Exception => e
        puts "INFO: client action class: #{controller_client_class_name}::#{action.name.capitalize} doesn't exist, #{e}"
      end

      return unless controller_action_class

      controller_action = controller_action_class.allocate
      copy_instance_variables(controller, controller_action)
      controller_action.initialize(params)
      controller_action.add_bindings unless options[:render_only]
    end

    # FIXME: similar method in action_view.rb
    def copy_instance_variables(object_from, object_to)
      object_from.instance_variables.each do |ivar|
        object_to.instance_variable_set(ivar, object_from.instance_variable_get(ivar))
      end
    end
  end
end
