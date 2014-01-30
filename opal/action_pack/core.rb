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

  def pluralize
    self + "s"
  end
end

class ActionController
  class Base
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def render_template
      ActionView.new.render(file: render_path)
    end

    def invoke_action(action)
      # set up default render path
      @render_path = self.class.to_s.split(/::/).join("/")
      controller.send(action)
    end

    protected

    def render(view)
      @render_path = (self.class.to_s.split(/::/)[0..-2] + view.to_s).join("/")
    end

    private

    def render_path
      @render_path
    end
  end
end

class ActionView
  def initialize(locals={})
    @locals = locals
  end

  def render(options={}, locals={}, &block)
    if options[:file]
      render_path = options[:file]
    elsif options[:partial]
      render_path = "_" + options[:partial]
    elsif options[:text]
      return options[:text]
    end
    @locals = locals
    Template[render_path].render(self)
  end

  def link_to(text, path)
    "<a href=\"#{path}\">#{text}</a>"
  end

  def resolve_path(path, *args)
    Application.instance.resolve_path(path, *args)
  end

  def method_missing(sym, *args, &block)
    sym_to_s = sym.to_s
    if @locals.has_key?(sym_to_s)
      return @locals[sym_to_s]
    elsif @locals.has_key?(sym)
      return @locals[sym]
    end

    m = /^(.*)_path$/.match(sym_to_s)
    if m
      return resolve_path(m[1], *args)
    end

    super
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

    def match_path(resource_name, action_name, *args)
      @routes.each do |route|
        action = route.match_path(resource_name, action_name, *args)
        return action if action
      end

      raise "no route matches path #{resource_name}::#{action_name}"
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
    def initialize(route, action_type, name, parts)
      @route = route
      @action_type = action_type
      @name = name
      @parts = parts
    end

    def match(parts, params)
      #puts "Action:match: parts: #{parts}, name: #{@name}, action_parts: #{@parts}"
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

    def match_path(action_name, *args)
      #puts "action_name = #{action_name}, name = #{@name}"
      return false unless @name.to_s == action_name.to_s

      if @action_type == :member
        if args.size == 1
          object = args.first
          if object.class == String
            object_id = object
          else
            object_id = object.id
          end
          #puts "object_id = #{object_id}, name = #{@name}"
          if @name.to_s == 'show'
            return object_id.to_s
          else
            return "#{object_id}/#{@name}"
          end
        else
          raise "requires one argument passed to member path"
        end
      else
        if args.size == 0
          #puts "Action#match_path: @name = #{@name}"
          if @name.to_s == 'index'
            return ""
          else
            return @name
          end
        else
          raise "argument passed to collection path"
        end
      end
    end

    def invoke_controller(action, params, options)
      controller_class_name = "#{@route.name.singularize.capitalize}Controller"
      #controller_class_name = "#{@route.name.capitalize}Controller"
      controller_class = Object.const_get(controller_class_name)

      if options[:render_view]
        controller = controller_class.new(params)
        controller.invoke_action(action)
        html = controller.render_template
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
        Action.new(self, :member,     :show,  [{id: '.*'}]),
        Action.new(self, :collection, :new,   ['new']),
        Action.new(self, :member,     :edit,  [{id: '.*'}, 'edit']),
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
        action_path = action.match_path(action_name, *args)
        #puts "action_path = #{action_path}"
        if action_path
          if action_path == ""
            return "/#{resource_name}"
          else
            return "/#{resource_name}/#{action_path}"
          end
        end
      end
      return nil
    end
  end

  def self.routes
    @routes ||= Router.new
  end

  def self.instance
    @application || new
  end

  def initialize
  end

  def launch(initial_url, initial_objects)
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

  def resolve_path(path, *args)
    m = /^((\w+)_)?(\w+)$/.match(path)
    if m
      resource = m[3]
      #puts "matched pattern: #{m}, resource = #{resource}"
      if m[1]
        action = m[2]
        #puts "multi part path, action = #{action}"
      else
        resource = m[3]
        if args.size == 0
          #puts "single part path, plural"
          action = 'index'
        else
          #puts "single part path, singular"
          action = 'show'
        end
      end
    else
      raise "unable to match path: #{path}_path"
    end

    self.class.routes.match_path(resource, action, *args)
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
