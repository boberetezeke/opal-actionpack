class Application
  class Route
    ALL_COLLECTION_ACTIONS = [:index]
    ALL_RESOURCE_ACTIONS = [:show, :new, :create, :edit, :update, :destroy]

    attr_reader :name, :redirect_action

    def initialize(name, options, &block)
      @name = name.to_s
      all_actions = [
        Action.new(self, :collection, name: :new,   parts: ['new']),
        Action.new(self, :member,     name: :edit,  parts: [{id: '.*'}, 'edit']),
        Action.new(self, :member,     name: :show,  parts: [{id: '.*'}]),
        Action.new(self, :collection, name: :index, parts: [])
      ]
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
        puts "Route:match: checking action: #{action}, parts[1..-1]=#{parts[1..-1]}, params=#{params}"
        if action.match(parts[1..-1], params)
          puts "Route:match: MATCHED"
          return action
        end
      end
      member_actions.each do |action|
        puts "Route:match: checking action: #{action}"
        if action.match(parts[1..-1], params)
          puts "Route:match: MATCHED"
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
    
    def match_path(resource_name, action_name, *args)
      puts "Route#match_path, name = #{@name}, resource_name = #{resource_name}"
      return nil unless @name.to_s == resource_name.to_s
      @actions.each do |action|
        action_path, params = action.match_path(action_name, *args)
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

        #puts "action_path = #{action_path}"
        #puts "params_string = #{params_string}"
        if action_path
          if action_path == ""
            url =  "/#{resource_name}"
          else
            url = "/#{resource_name}/#{action_path}"
          end

          return params_string.empty? ? url : "#{url}?#{params_string}"
        end
      end
      return nil
    end
  end
end
