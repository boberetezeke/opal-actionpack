class Application
  class Route
    ALL_COLLECTION_ACTIONS = [:index]
    ALL_RESOURCE_ACTIONS = [:show, :new, :create, :edit, :update, :destroy]

    attr_reader :name

    def initialize(name, options)
      @name = name.to_s
      @actions = [
        Action.new(self, :collection, :new,   ['new']),
        Action.new(self, :member,     :edit,  [{id: '.*'}, 'edit']),
        Action.new(self, :member,     :show,  [{id: '.*'}]),
        Action.new(self, :collection, :index, [])
      ]
    end

    def match(parts, params)
      #puts "Route:match: parts: #{parts}, name: #{@name}"
      return nil unless @name == parts[0]
      @actions.each do |action|
        return action if action.match(parts[1..-1], params)
      end
      return nil
    end

    def match_path(resource_name, action_name, *args)
      #puts "Route#match_path, name = #{@name}, resource_name = #{resource_name}"
      return nil unless @name.to_s == resource_name.to_s
      @actions.each do |action|
        action_path, params = action.match_path(action_name, *args)
        # FIXME: need to url encode parameters
        params_string = params.map{|key, value| "#{key}=#{value}"}.join("&")

        #puts "action_path = #{action_path}"
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
