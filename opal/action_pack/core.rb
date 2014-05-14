class Template
  def self.current_output_buffer
    @output_buffer
  end

  def self.current_output_buffer=(output_buffer)
    @output_buffer = output_buffer
  end

  def render(ctx = self)
    self.class.current_output_buffer = OutputBuffer.new
    ctx.instance_exec(self.class.current_output_buffer, &@body)
  end

  class OutputBuffer
    def initialize
      @buffer_stack = []
      @buffer = []
    end

    def push_buffer
      @buffer_stack.push(@buffer)
      @buffer = []
    end

    def pop_buffer
      @buffer = @buffer_stack.pop
    end

    def append(str)
      @buffer << str
    end

    alias append= append

    def join
      @buffer.join
    end
  end
end

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

  # OPAL-CHG-4: implement
  def html_safe
    self
  end
end

class History
  def self.push_state(state_object, title, url)
    #`window.history.pushState({}, title, url)`
  end

  def self.pop_state
    `window.history.back()`
  end

  def self.on_pop_state(&block)
    %x{
      self = this;
      window.onpopstate = function(event) {
        block();
      }
    }
  end
end


module PathHandler
  def resolve_path(root, *args)
    @application.resolve_path(root, *args)
  end

  def method_missing(sym, *args, &block)
    sym_to_s = sym.to_s
    m = /^(.*)_path$/.match(sym_to_s)
    if m
      return @application.resolve_path(m[1], *args)
    end

    super
  end
end

class ActionController
  class Base
    include PathHandler

    attr_reader :params

    def initialize(params)
      @application = Application.instance
      @params = params
    end

    def render_template
      ActionView::Renderer.new.render(self, file: render_path)
    end

    def invoke_action(action)
      # set up default render path
      @render_path = "views" + "/" + view_path + "/" + action.name
      self.send(action.name)
    end

    def view_path
      controller_parts = self.class.to_s.split(/::/)
      controller_parts = controller_parts[0..-2].map{|part| part.downcase} + [controller_root_name(controller_parts[-1])]
      controller_parts.join("/")
    end

    def controller_root_name(controller_name)
      /^(.*)Controller$/.match(controller_name)[1].downcase
    end

    private

    def render_path
      @render_path
    end
  end
end

module ActionView
  class Renderer
    include ::ActionView::Helpers::FormHelper
    include ::ActionView::RecordIdentifier
    include ::ActionView::ModelNaming

    include PathHandler
    attr_reader :absolute_path

    INITIALIZE_DEFAULTS={locals: {}, path: ""}
    def initialize(options={})
      options = INITIALIZE_DEFAULTS.merge(options) 
      @path = options[:path]
      @application = Application.instance
      # Opal / RMI diff ("".split(/\//) == [""] vs []
      if @path == ""
        @path_parts = []
      else
        @path_parts = @path.split(/\//)
      end
      @locals = options[:locals]
      @absolute_path = ""
    end

    def render(controller, options={}, locals={}, &block)
      options = controller if controller.is_a?(Hash)

      if options[:file]
        render_path = options[:file]
        @absolute_path = render_path
      elsif options[:partial]
        partial_parts = options[:partial].split(/\//)
        render_path = (@path_parts + partial_parts[0..-2] + ["_" + partial_parts[-1]]).join("/")
      elsif options[:text]
        return options[:text]
      end
      @locals = locals
      copy_instance_variables_from(controller)
      Template[render_path].render(self)
    end

    def capture(*args, &block)
      puts "capture: args = #{args}"
      Template.current_output_buffer.push_buffer
      value = block.call(*args)
      Template.current_output_buffer.pop_buffer
      puts "capture: value = #{value}"
      if value.is_a?(Array)
        value.join
      else
        value
      end
    end

    def copy_instance_variables_from(object)
      object.instance_variables.each do |ivar|
        self.instance_variable_set(ivar, object.instance_variable_get(ivar))
      end
    end

    def content_for(sym, &block)
      # FIXME: need to implement
    end

    # OPAL-CHG-3 - need to implement all/most of UrlHelper
    def url_for(url_for_options)
      # FIXME: need to implement
      "some_url"
    end

    def link_to(text, path, options={})
      "<a href=\"#{path}\"" + options.map{|k,v| "#{k}=\"#{v}\""}.join(' ') + ">#{text}</a>"
    end

    # NOTE: stolen from url_helper
    def token_tag(token=nil)
      # no need for token_tag as we won't do real submits
      ""
    end

    def method_tag(method)
      tag('input', type: 'hidden', name: '_method', value: method.to_s)
    end

    def method_missing(sym, *args, &block)
      sym_to_s = sym.to_s
      if @locals.has_key?(sym_to_s)
        return @locals[sym_to_s]
      elsif @locals.has_key?(sym)
        return @locals[sym]
      end

      super
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
        #puts "matching parts=#{parts.inspect}, route=#{route.inspect}"
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
      #puts "Action:match: parts: #{parts.inspect}, name: #{@name}, action_parts: #{@parts.inspect}"
      return false if parts.size != @parts.size
      return true if parts.size == 0

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
      #puts "action_name = #{action_name}, name = #{@name}, args = #{args.inspect}"
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
          return [action_root, params]
        else
          raise "argument passed to collection path"
        end
      end
    end

    def invoke_controller(action, params, options)
      puts "invoke_controller#render_view 0"
      if options[:render_view]
        puts "invoke_controller#render_view 1"
        controller_class_name = "#{@route.name.capitalize}Controller"
        puts "invoke_controller#render_view 2"
        controller_class = Object.const_get(controller_class_name)
        puts "invoke_controller#render_view 3"
        controller = controller_class.new(params)
        puts "invoke_controller#render_view 4"
        controller.invoke_action(action)
        puts "invoke_controller#render_view 5"
        html = controller.render_template
        puts "invoke_controller#render_view 6, html = #{html}"
        Document.find(options[:selector]).html = html
      end
      puts "invoke_controller#render_view 7"

      controller_client_class_name = "#{@route.name.capitalize}ClientController"
      begin
        controller_client_class = Object.const_get(controller_client_class_name)
        begin
          controller_action_class = controller_client_class.const_get(action.name.capitalize)
          controller_action = controller_action_class.new(params)
          controller_action.add_bindings
        rescue Exception => e
          puts "client class: #{controller_client_class_name}::#{action.name.capitalize} doesn't exist, #{e}"
        end
      rescue 
        puts "client class: #{controller_client_class_name} doesn't exist"
      end
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

  def self.routes
    @routes ||= Router.new
  end

  def self.instance
    return @@application if defined?(@@application)
    @@application = new
  end

  def initialize
    @store = get_store
    ActiveRecord::Base.connection = @store
  end

  def get_store
    ActiveRecord::MemoryStore.new
  end

  def launch(initial_objects_json)
    begin
      initial_path = `window.location.pathname`
      initial_hash = `window.location.hash`
      initial_search = `window.location.search`

      initial_url = initial_path + initial_search

      puts "initial_path = #{initial_path}"
      puts "initial_hash = #{initial_hash}"
      puts "initial_search = #{initial_search}"
      puts "initial_url = #{initial_url}"
      @objects = ActiveRecord::Base.new_objects_from_json(initial_objects_json)
      puts "object from json = #{@objects}"
      @objects.each { |object| object.save }
      go_to_route(initial_url, render_view: false)
    rescue Exception => e
      puts "Application Exception: #{e}"
      e.backtrace.each do |trace|
        puts trace
      end
    end
  end

  def resolve_path(path, *args)
    # FIXME: can't detect plural by checking for trailing 's'
    m = /^((\w+)_)?((\w+?)(s)?)$/.match(path)
    if m
      action_with_underscore = m[1]
      action = m[2]
      resource = m[3]
      resource_root = m[4]
      is_plural = m[5]

      #puts "matched pattern: #{m}, action = #{action.inspect}, resource = #{resource}, is_plural=#{is_plural.inspect}"
      if action_with_underscore
        #puts "multi part path, action = #{action}"
        if !is_plural
          resource = resource.pluralize
        end
      else
        if is_plural
          #puts "single part path, plural"
          action = 'index'
        else
          #puts "single part path, singular"
          resource = resource.pluralize
          action = 'show'
        end
      end
    else
      raise "unable to match path: #{path}_path"
    end

    self.class.routes.match_path(resource, action, *args)
  end

  def go_to_route(url, options={})
    puts "go_to_route 1"
    @current_route_action, @params = self.class.routes.match_url(url)
    puts "go_to_route 2"
    @current_route_action.invoke_controller(@current_route_action, @params, options)
    puts "go_to_route 3"
    History.push_state({}, 'new route', url)
  end

  ROUTE_MAP = {
    "Calculator" => {route: 'calculators', key: 'calculator'},
    "Results" => {route: 'results', key: 'result'}
  }

  def connect
    @store.on_change do |change_type, object|
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
