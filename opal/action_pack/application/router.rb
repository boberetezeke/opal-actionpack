class Application
  class Router
    include SemanticLogger::Loggable

    def initialize
      @routes = []
    end

    def draw(&block)
      instance_exec(&block)
    end

    def resource(route, options={}, &block)
      @routes.push(Route.new(route, true, options, &block))
    end

    def resources(route, options={}, &block)
      @routes.push(Route.new(route, false, options, &block))
    end

    def root(options={})
      #puts "Router#root: options: #{options}"
      to = options[:to]
      controller_name, action_name = to.split(/#/)
      action = find_action([controller_name, action_name], {})
      # FIXME: need to figure out what is_singular parameter should be
      @root_route = Route.new(controller_name, false, redirect_action: action)
    end

    def match_url(url)
      #puts "Router#match_url(#{url})"
      parts, params = UrlParser.to_parts(url)

      if parts == []
        return [@root_route.redirect_action, params]
      end

      action = find_action(parts, params)
      return [action, params] if action

      raise "no route matches #{url}"
    end

    def paths
      @routes.inject([]) do |sum, route|
        sum + route.paths
      end
    end

    def match_path_method(method_name, args)
      @routes.each do |route|
        action = route.match_path_method(method_name, args)
        return action if action
      end
    end

    def match_path(resource_name, action_name, *args)
      #puts "Router#match_path(resource_name: #{resource_name}, action: #{action_name}, args: #{args})"
      @routes.each do |route|
        action = route.match_path(resource_name, action_name, *args)
        return action if action
      end

      raise "no route matches path #{resource_name}::#{action_name}"
    end

    private

    def find_action(parts, params)
      #puts "Router#find_action: #{parts}, #{params}"
      @routes.each do |route|
        #puts "Router#find_action: matching parts=#{parts.inspect}, route=#{route.name}"
        if action = route.match(parts, params)
          return action
        end
      end

      return nil
    end
  end
end
