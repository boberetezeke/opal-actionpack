class Application
  class Route
    include SemanticLogger::Loggable

    ALL_COLLECTION_ACTIONS = [:index]
    ALL_RESOURCE_ACTIONS = [:show, :new, :create, :edit, :update, :destroy]

    attr_reader :name, :redirect_action

    def initialize(name, is_singular, options, &block)
      @name = name.to_s
      @is_singular = is_singular

      if @is_singular
        all_actions = [
          Action.new(self, :collection, name: :new,   parts: ['new']),
          Action.new(self, :member,     name: :edit,  parts: ['edit']),
          Action.new(self, :member,     name: :show,  parts: []),
          
          Action.new(self, :member,     name: :destroy, parts: []),
          Action.new(self, :member,     name: :update,  parts: []),
          Action.new(self, :member,     name: :create,  parts: []),
        ]
      else
        all_actions = [
          Action.new(self, :collection, name: :new,   parts: ['new']),
          Action.new(self, :member,     name: :edit,  parts: [{id: '.*'}, 'edit']),
          Action.new(self, :member,     name: :show,  parts: [{id: '.*'}]),
          Action.new(self, :collection, name: :index, parts: []),
          
          Action.new(self, :member,     name: :destroy, parts: [{id: '.*'}]),
          Action.new(self, :member,     name: :update,  parts: [{id: '.*'}]),
          Action.new(self, :member,     name: :create,  parts: [{id: '.*'}]),
        ]
      end
      if options[:only]
        onlys = options[:only].is_a?(Array) ? options[:only] : [options[:only]]
        @actions = all_actions.select{|action| onlys.include?(action.name)}
      elsif options[:except]
        exceptions = options[:except].is_a?(Array) ? options[:except] : [options[:except]]
        @actions = all_actions.reject{|action| exceptions.include?(action.name)}
      elsif options[:redirect_action]
        @redirect_action =  Action.new(self, :redirect, redirect_action: options[:redirect_action])
      else
        @actions = all_actions
      end

      instance_exec(&block) if block
    end

    def member(&block)
      @action_type = :member
      instance_exec(&block)
    end

    def collection(&block)
      @action_type = :collection
      instance_exec(&block)
    end

    def get(name)
      @actions << Action.new(self, @action_type, name: name, method: :get)
    end

    def post(name)
      @actions << Action.new(self, @action_type, name: name, method: :post)
    end

    def put(name)
      @actions << Action.new(self, @action_type, name: name, method: :put)
    end

    def delete(name)
      @actions << Action.new(self, @action_type, name: name, method: :delete)
    end

    def match(parts, params)
      #puts "Route:match: parts: #{parts}, name: #{@name}"
      return nil unless @name == parts[0]
      collection_actions.each do |action|
        logger.debug "Route:match: checking action: #{action}, parts[1..-1]=#{parts[1..-1]}, params=#{params}"
        if action.match(parts[1..-1], params)
          logger.debug "Route:match: MATCHED"
          return action
        end
      end
      member_actions.each do |action|
        logger.debug "Route:match: checking action: #{action}"
        if action.match(parts[1..-1], params)
          logger.debug "Route:match: MATCHED"
          return action
        end
      end
      return nil
    end
    
    def collection_actions
      @actions.select{|action| action.action_type == :collection}
    end
    
    def member_actions
      @actions.select{|action| action.action_type == :member}
    end

    def to_s
      "actions = #{@actions}"
    end

    def paths
      @actions.map do |action|
        path_method_name_for_action(action)
      end
    end

    def match_path_method(method_name, args)
      @actions.each do |action|
        if path_method_name_for_action(action) == method_name
          if action.action_type == :member
            if args.size == 0
              raise "argument required for member path"

            # FIXME - need to implement the way that rails detects an ActiveModel object or an id
            elsif args.first.is_a?(ActiveRecord::Base) || args.first.to_i != 0
              raise "argument required for member path must be either a active model object or id value"
            else
              return action
            end
          else
            return action
          end
        end
      end

      return nil
    end

    def path_method_name_for_action(action)
      if action.action_type == :collection
        if action.name.to_s == 'index'
          @name
        else
          "#{action.name}_#{@name}"
        end
      else
        if action.name.to_s == 'show'
          if @is_singular
            @name
          else
            @name.to_s.singularize
          end
        else
          if @is_singular
            "#{action.name}_#{@name}"
          else
            "#{action.name}_#{@name.to_s.singularize}"
          end
        end
      end
    end

    def match_path(resource_name, action_name, *args)
      logger.debug "Route#match_path, name = #{@name}, resource_name = #{resource_name}"

      # return nil unless @name.to_s == resource_name.to_s

      singularized_resource_name = @is_singular ? resource_name : resource_name.singularize
      pluralized_resource_name = resource_name.pluralize unless @is_singular

      @actions.each do |action|
        if action.action_type == :member || action.name.to_s == 'new'
          logger.debug "for member action #{action}, checking #{@name.to_s.singularize} == #{singularized_resource_name}"
          next if resource_name != singularized_resource_name
          next if @name.to_s.singularize != singularized_resource_name

          returned_resource_name = @is_singular ? resource_name : pluralized_resource_name
        else
          logger.debug "for collection action #{action}, checking #{@name} == #{pluralized_resource_name}"
          next if resource_name != pluralized_resource_name
          next if @name.to_s != pluralized_resource_name

          returned_resource_name = @is_singular ? resource_name : pluralized_resource_name
        end

        action_path, params = action.match_path(action_name, @is_singular, *args)
        # FIXME: need to url encode parameters
        # FIXME: Need to handle nested hashes like 
        #          {table: {order: 'x', position: 'y'}} 
        #        should be
        #          table[order]=x&table[position]=y
        #
        #        {table: {sub_table1: {order: 'x', position: 'y'}}
        #          should be
        #        table[sub_table1][order]=x&table[sub_table1][position]=y
        #
        params_string = params.map{|key, value| "#{key}=#{value}"}.join("&")

        logger.debug "action_path = #{action_path}"
        logger.debug "params_string = #{params_string}"

        if action_path
          if action_path == ""
            url =  "/#{returned_resource_name}"
          else
            url = "/#{returned_resource_name}/#{action_path}"
          end

          return params_string.empty? ? url : "#{url}?#{params_string}"
        end
      end
      return nil
    end
  end
end
