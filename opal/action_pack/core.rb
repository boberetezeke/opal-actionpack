class String
  def capitalize
    self[0..0].upcase + self[1..-1]
  end

  def singularize
    if m = /^(.*)s$/.match(self)
      return m[1]
    end
    self
  end
end

class ActionController
  class Base
    attr_reader :params

    def initialize(params)
      @params = params
    end
  end
end

class Application
  class Router
    def initialize
      @routes = []
    end

    def draw
      yield self
    end

    def resources(route, options={})
      @routes.push(Route.new(route, options))
    end

    def match_url(url)
      parts, params = to_parts(url)

      @routes.each do |route|
        if action = route.match(parts, params)
          return [action, params] 
        end
      end

      raise "no route matches #{url}"
    end

    def to_parts(url)
      # remove leading '/'
      if m = /^\/(.*)$/.match(url)
        url = m[1]
      end

      # separate url on ?
      if m = /^([^?]*)\?(.*)$/.match(url)
        url = m[1]
        keys_and_values = m[2].split(/&/)
        params = {}
        keys_and_values.each do |key_and_value|
          key, value = key_and_value.split(/=/)
          params[key] = value
        end
      else
        params = {}
      end

      [url.split(/\//), params]
    end
  end

  class Action
    attr_reader :name
    def initialize(route, name, parts)
      @route = route
      @name = name
      @parts = parts
    end

    def match(parts, params)
      return false if parts.size != @parts.size

      @parts.each_with_index do |part, index|
        if part.class == String
          return true if /#{part}/.match(parts[index])
        else
          param_key = part.keys.first
          matcher = /(#{part.values.first})/
          if m = matcher.match(parts[index])
            params[param_key] = m[1]
            return true
          end
        end
      end
      return false
    end

    def invoke_controller(action, params, options)
      controller_class_name = "#{@route.name.singularize.capitalize}Controller"
      #controller_class_name = "#{@route.name.capitalize}Controller"
      controller_class = Object.const_get(controller_class_name)

      if options[:render_view]
        controller = controller_class.new(params)
        controller.send(action)
        html = Template[controller.render_path].render(controller)
        Document.find(options[:selector]).html = html
      end

      controller_action_class = controller_class.const_get(action.name.capitalize)
      controller_action = controller_action_class.new(params)
      controller_action.add_bindings
    end

  end

  class Route
    ALL_COLLECTION_ACTIONS = [:index]
    ALL_RESOURCE_ACTIONS = [:show, :new, :create, :edit, :update, :destroy]

    attr_reader :name

    def initialize(name, options)
      @name = name.to_s
      @actions = [
        Action.new(self, :show,  [{id: '.*'}]),
        Action.new(self, :new,   ['new']),
        Action.new(self, :edit,  [{id: '.*'}, 'edit']),
        Action.new(self, :index, [])
      ]
    end

    def match(parts, params)
      return nil unless @name == parts[0]
      @actions.each do |action|
        return action if action.match(parts[1..-1], params)
      end
      return nil
    end
  end

  def self.routes
    @routes ||= Router.new
  end

  def initialize(initial_url, initial_objects)
    begin
      @memory_store = ActiveRecord::MemoryStore.new
      @objects = [initial_objects]
      ActiveRecord::Base.connection = @memory_store
      @objects.each { |object| object.save }
      go_to_route(initial_url, render_view: false)
    rescue Exception => e
      puts "Exception: #{e}"
      e.backtrace[0..10].each do |trace|
        puts trace
      end
    end
  end

  def go_to_route(url, options={})
    @current_route_action, @params = self.class.routes.match_url(url)
    @current_route_action.invoke_controller(@current_route_action, @params, options)
  end

  ROUTE_MAP = {
    "Calculator" => {route: 'calculators', key: 'calculator'},
    "Results" => {route: 'results', key: 'result'}
  }

  def connect
    @memory_store.on_change do |change_type, object|
      route = "/" + ROUTE_MAP[object.class.to_s][:route]
      key = ROUTE_MAP[object.class.to_s][:key]
      case change_type
      when :insert
        puts "INSERT: #{object}"
        HTTP.post route, {:payload => {:key => object.to_json}} 
      when :delete
        puts "DELETE: #{object}"
      when :update
        puts "UPDATE: #{object}"
        HTTP.put "#{route}/#{object.id}", object.attributes do |response|
        end
      end
    end
  end
end

=begin
class Node
  attr_reader :children
  def initialize(name=nil)
    @name = name
    @children = []
  end
 
  def node(name, &block)
    child = Node.new(name)
    @children.push(child)
    child.instance_exec(&block) if block
  end
 
  def instance_exec(*args, &block)
    method_name = nil
      n = 0
      n += 1 while respond_to?(method_name = "__instance_exec#{n}")
      self.class.instance_eval { define_method(method_name, &block) }
 
    begin
      send(method_name, *args)
    ensure
      self.class.instance_eval { remove_method(method_name) } rescue nil
    end
  end
 
  def to_s
    
    @name + "[" + @children.map{|child| child.to_s}.join(", ") + "]"
  end
end
 
def tree(name, &block)
  @tree = Node.new(name)
  @tree.instance_exec(&block)
  @tree
end
 
tree("Simpsons family tree") do
  node("gramps") do
    node("homer+marge") do
      node("bart")
      node("lisa")
      node("maggie")
    end
  end
end
=end
