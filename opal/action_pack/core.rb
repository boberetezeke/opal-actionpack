class String
   def underscore
    if RUBY_ENGINE == 'opal'
      `#{self}.replace(/([A-Z\d]+)([A-Z][a-z])/g, '$1_$2')
      .replace(/([a-z\d])([A-Z])/g, '$1_$2')
      .replace(/-/g, '_')
      .toLowerCase()`
    else
      # stolen (mostly) from Rails::Activesupport
      return self unless self =~ /[A-Z-]|::/
      word = self.to_s.gsub('::', '/')
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
  end
end

class Template
  def self.current_output_buffer
    #puts "in self.current_output_buffer: (#{@output_buffer_stack.size})"
    @output_buffer
  end

  def self.current_output_buffer=(output_buffer)
    @output_buffer_stack ||= []
    @output_buffer_stack.push(@output_buffer) 
    @output_buffer = output_buffer
  end

  def self.output_buffer_stack
    @output_buffer_stack ||= []
  end

  def self.pop_output_buffer
    @output_buffer = @output_buffer_stack.pop
  end

  def render(ctx = self)
    self.class.current_output_buffer = OutputBuffer.new(self.class.output_buffer_stack.size)
    result = ctx.instance_exec(self.class.current_output_buffer, &@body)
    self.class.pop_output_buffer
    result
  end

  class OutputBuffer
    def initialize(id)
      @id = id
      @buffer_id = 0
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): initialize: #{@buffer.inspect}"
      @buffer_stack = []
      @buffer = []
    end

    def push_buffer
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): pushing buffer: #{@buffer.inspect}"
      @buffer_id += 1
      @buffer_stack.push(@buffer)
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): pushing to buffer stack: #{@buffer_stack.inspect}"
      @buffer = []
    end

    def pop_buffer
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): popping buffer: #{@buffer.inspect}"
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): popping buffer stack: #{@buffer_stack.inspect}"
      @buffer_id -= 1
      @buffer = @buffer_stack.pop
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): after popping buffer: #{@buffer.inspect}"
    end

    def append(str)
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): append: #{str.inspect}"
      @buffer << str
    end

    alias append= append

    def join
      #puts "OutputBuffer(#{@id}, #{@buffer_id}): join: #{@buffer.join.inspect}"
      @buffer.join
    end
  end
end

class String
  def capitalize
    self[0..0].upcase + self[1..-1]
  end

  def camelize
    self.split(/_/).map{|s| s.capitalize}.join
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

  def blank?
    self.empty?
  end
end

class Array
  def blank?
    self.empty?
  end
end

class Hash
  def blank?
    self.empty?
  end
end

class TrueClass
  def blank?
    false
  end
end

class FalseClass
  def blank?
    false
  end
end

class NilClass
  def blank?
    true
  end
end

class Object
  def capture_exception
    begin
      yield
    rescue Exception => e
      puts "Exception: #{e}"
      e.backtrace[0..10].each do |bt|
        puts bt
      end
    end      
  end

  def present?
    !blank?
  end
end

class History
  def self.push_state(state_object, title, url)
    `window.history.pushState({}, title, url)`
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

    class BoundEvent < Struct.new(:event, :selector); end

    def self.helper_method(sym)
      if !defined?(@@helper_methods)
        @@helper_methods = {}
      end
      @@helper_methods[sym] = true
    end

    def self.helper_methods
      if !defined?(@@helper_methods)
        @@helper_methods = {}
      end
      @@helper_methods
    end

    def initialize(params)
      @application = Application.instance
      @params = params
      @bound_events = {}
    end

    def helper_methods
      self.class.helper_methods
    end

    def session
      @application.session
    end

    def render_template(options={})
      content_fors = options.delete(:content_for) || {}
      partial = options[:partial]

      renderer = ActionView::Renderer.new(self, path: render_path)
      if partial
        top_view_html = renderer.render(options)
      else
        top_view_html = renderer.render(file: render_path)
      end

      content_for_htmls = {}
      content_fors.each do |key, selector|
        content_for_html = renderer.content_fors[key]
        puts "content for #{key} = #{content_for_html}"
        content_for_htmls[selector] = content_for_html
      end
      [top_view_html, content_for_htmls]
    end

    def render(name_or_options)
      if name_or_options.is_a?(Hash)
        build_render_path("dummy")
        render_template(name_or_options)
      else
        build_render_path(name_or_options)
      end
    end

    def invoke_action(action)
      # set up default render path
      @render_path = "views" + "/" + view_path + "/" + action.name
      self.send(action.name)
    end

    def build_render_path(name)
      @render_path = "views" + "/" + view_path + "/" + name
    end

    def view_path
      controller_parts = self.class.to_s.split(/::/)
      #puts "controller_parts = #{controller_parts}"
      if m = (/^(.*)ClientController$/.match(controller_parts[0]))
        controller_parts = [m[1].underscore] 
      else
        controller_parts = controller_parts[0..-2].map{|part| part.underscore} + [controller_root_name(controller_parts[-1])]
      end

      #puts "controller_parts = #{controller_parts}"
      view_path = controller_parts.join("/")
      #puts "view_path = #{view_path}"
      view_path
    end

    def controller_root_name(controller_name)
      /^(.*)Controller$/.match(controller_name)[1].underscore
    end

    def go_to_route(*args, &block)
      if args.last.is_a?(Hash)
        new_args = args[0..-2]
        options = args.last
      else
        options = {}
      end

      manual_unbind = options.delete(:manual_unbind)
      unbind_all_events unless manual_unbind

      @application.go_to_route(*(new_args + [options]), &block)
    end

    def bind_event(selector, event)
      @bound_events[selector] = BoundEvent.new(event, selector)
      Element.find(selector).on(event) do
        puts "#{selector}: #{event}"
        capture_exception do
          yield
        end
        false
      end
    end
    
    def unbind_event(selector, event)
      bound_event = @bound_events.delete(selector)
      Element.find(bound_event.selector).off(bound_event.event) 
    end

    def unbind_all_events
      @bound_events.values.each {|bound_event| unbind_event(bound_event.selector, bound_event.event)}
    end

    def unbind_events(*selectors)
      selectors.flatten.each do |selector| 
        unbind_event(selector)
      end
    end

    def current_path
      `window.location.pathname`
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
    attr_reader :absolute_path, :content_fors

    INITIALIZE_DEFAULTS={locals: {}, path: ""}
    def initialize(controller, options={})
      options = INITIALIZE_DEFAULTS.merge(options) 

      @controller = controller
      @application = Application.instance
      @top_renderer = options[:top_renderer] || self

      @content_fors = {}

      helper_module = options[:helper_module]
      helper_module = helper_module_from_controller(@controller) unless helper_module

      include_helpers(helper_module) if helper_module

      if options[:path_parts]
        @path_parts = options[:path_parts].dup
        @path = @path_parts.join('/')
      else
        @path = options[:path]
        # Opal / RMI diff ("".split(/\//) == [""] vs []
        if @path == ""
          @path_parts = []
        else
          @path_parts = @path.split(/\//)
          @path_parts = @path_parts[0..-2] unless @path_parts.empty?
        end
      end
      @locals = options[:locals]
      @absolute_path = ""
    end

    DEFAULT_RENDER_OPTIONS = {locals: {}}
    def render(options={}, &block)
      options = DEFAULT_RENDER_OPTIONS.merge(options)
      if options[:file]
        render_path = options[:file]
        @absolute_path = render_path
      elsif options[:partial]
        partial_parts = options[:partial].split(/\//)
        #puts "render:partial: #{partial_parts}, #{@path_parts}"

        helper_module = nil
        if partial_parts.size == 1
          path_parts = @path_parts
        else
          helper_module = helper_module_from_view_path(partial_parts.first)
          path_parts = @path_parts[0..-2]
        end
        render_path = (path_parts + partial_parts[0..-2] + ["_" + partial_parts[-1]]).join("/")

        new_options = options.dup
        new_options.delete(:partial)
        new_options.merge!(file: render_path)
        return self.class.new(@controller, path_parts: @path_parts, helper_module: helper_module, top_renderer: @top_renderer).render(new_options, &block)
      elsif options[:text]
        return options[:text]
      end
      @locals = options[:locals]
      copy_instance_variables_from(@controller)
      template = Template[render_path]
      if !template
        raise "unable to find template: #{render_path} in paths: #{Template.paths}"
      else
        template.render(self)
      end
    end

    def capture(*args, &block)
      #puts "capture: args = #{args}"
      Template.current_output_buffer.push_buffer
      value = block.call(*args)
      Template.current_output_buffer.pop_buffer
      #puts "capture: value = #{value}"
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

    def include_helpers(helper_module)
      application_helper = Object.const_get('ApplicationHelper')
      if application_helper
        self.class.include(application_helper)
      end

      if helper_module
        self.class.include(helper_module)
      end
    end

    def helper_module_from_controller(controller)
      controller_class_name = controller.class.to_s
      match = /^(.*?)(Client)?Controller/.match(controller_class_name)
      if match
        controller_name = match[1]
        helper_module_name = "#{controller_name}Helper"
        begin
          Object.const_get(helper_module_name)
        rescue Exception
          return nil
        end
      else
        return nil
      end
    end

    def helper_module_from_view_path(view_path)
      helper_module_name = "#{view_path.camelize}Helper"
      begin
        Object.const_get(helper_module_name)
      rescue Exception
        return nil
      end
    end

    def content_for(sym, &block)
      # FIXME: need to implement
      puts "content_for(entry): sym = #{sym}"
      content = capture(&block)
      puts "content_for: sym = #{sym}, content = #{content}"
      @top_renderer.content_fors[sym] = content
    end

    # OPAL-CHG-3 - need to implement all/most of UrlHelper
    def url_for(url_for_options)
      # FIXME: need to implement
      "some_url"
    end

    def link_to(text, path, options={})
      "<a href=\"#{path}\"" + options.map{|k,v| "#{k}=\"#{v}\""}.join(' ') + ">#{text}</a>"
    end

    DEFAULT_POLYMORPHIC_PATH_OPTIONS = {format: :post}
    def polymorphic_path(record, options={})
      options = DEFAULT_POLYMORPHIC_PATH_OPTIONS.merge(options)
      #OPAL-CHG-2
      #Application.routes.match_path(record.class.to_s, options[:format], record.id)
      "/#{record.class.to_s}/#{record.id}"
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
      elsif @controller && @controller.helper_methods.has_key?(sym)
        return @controller.send(sym)
      end

      #puts "Renderer method_missing: #{sym}, locals = #{@locals}, helper_methods = #{@controller ? @controller.helper_methods : 'no controller'}"

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
        puts "Router#match_url: matching parts=#{parts.inspect}, route=#{route.inspect}"
        if action = route.match(parts, params)
          return [action, params] 
        end
      end

      raise "no route matches #{url}"
    end

    def match_path(resource_name, action_name, *args)
      #puts "Router#match_path(resource_name: #{resource_name}, action: #{action_name}, args: #{args})"
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
          return [action_root, params]
        else
          raise "argument passed to collection path"
        end
      end
    end

    def invoke_controller(action, params, options)
      if options[:render_view]
        controller_class_name = "#{@route.name.camelize}Controller"
        controller_class = Object.const_get(controller_class_name)
        controller = controller_class.new(params)
        controller.invoke_action(action)
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
        #puts "INFO: client class: #{controller_client_class_name} doesn't exist"
      end

      return unless controller_client_class

      begin
        controller_action_class = controller_client_class.const_get(action.name.capitalize)
      rescue Exception => e
        #puts "INFO: client action class: #{controller_client_class_name}::#{action.name.capitalize} doesn't exist, #{e}"
      end

      return unless controller_action_class

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

  def self.routes
    @routes ||= Router.new
  end

  def self.instance
    return @@application if defined?(@@application)
    @@application = new
  end

  attr_reader :session

  def initialize
    @store = get_store
    ActiveRecord::Base.connection = @store
  end

  def get_store
    ActiveRecord::MemoryStore.new
  end

  def launch(initial_objects_json, session={})
    capture_exception do
      initial_path = `window.location.pathname`
      initial_hash = `window.location.hash`
      initial_search = `window.location.search`

      initial_url = initial_path + initial_search

      #puts "initial_path = #{initial_path}"
      #puts "initial_hash = #{initial_hash}"
      #puts "initial_search = #{initial_search}"
      #puts "initial_url = #{initial_url}"
      @objects = ActiveRecord::Base.new_objects_from_json(initial_objects_json, nil, from_remote: true)
      @objects.each { |object| object.save(from_remote: true) }
      @session = JSON.parse(session)
      go_to_route(initial_url, render_view: false)
    end
  end

  def resolve_path(path, *args)
    # FIXME: can't detect plural by checking for trailing 's'
    #puts "resolve_path: #{path}, args = #{args}"
    m = /^(([^_]+)_)?((\w+?)(s)?)$/.match(path)
    if m
      action_with_underscore = m[1]
      action = m[2]
      resource = m[3]
      resource_root = m[4]
      is_plural = m[5]

      #puts "resolve_path: matched pattern: #{m}, action = #{action.inspect}, resource = #{resource}, is_plural=#{is_plural.inspect}"
      if action_with_underscore
        #puts "resolve_path: multi part path, action = #{action}"
        if !is_plural
          resource = resource.pluralize
        end
      else
        if is_plural
          #puts "resolve_path: single part path, plural"
          action = 'index'
        else
          #puts "resolve_path: single part path, singular"
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
    #puts "go_to_route: url = #{url}"
    @current_route_action, @params = self.class.routes.match_url(url)
    #puts "before push_state"
    History.push_state({}, 'new route', url)
    #puts "go_to_route: action = #{@current_route_action.name}, params = #{@params}"
    @current_route_action.invoke_controller(@current_route_action, @params, options)
    #puts "go_to_route: after invoke_controller"
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
        #puts "INSERT: #{object}"
        HTTP.post route, {:payload => {:key => object.to_json}} 
      when :delete
        #puts "DELETE: #{object}"
      when :update
        #puts "UPDATE: #{object}"
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
