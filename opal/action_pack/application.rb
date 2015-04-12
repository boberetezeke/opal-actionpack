class Application
  def self.routes
    @routes ||= Router.new
  end

  def self.instance
    return @@application if defined?(@@application)
    @@application = new
    #puts "@@application = #{@@application}"
    @@application
  end

  attr_reader :session

  def initialize
    #puts "in initialize of class #{self.class.to_s}"
    @store = get_store
    ActiveRecord::Base.connection = @store
  end

  def is_server?
    false
  end

  def is_client?
    true
  end

  def routes
    self.class.routes
  end

  def get_store
    ActiveRecord::MemoryStore.new
  end

  def launch(initial_objects_json, session={}, block=Proc.new)
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
      #puts "objects = #{@objects}"
      @objects.each { |object| object.save(from_remote: true) }
      @session = JSON.parse(session)

      #yield if block_given?
      block.call if block

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

  # 
  # Goes to the route specified as passes options on to invoke_controller
  #
  # This uses the history API to push this route on the browser's history stack.
  # Then it invokes the server side controller, optionally render's the view and then
  # invokes the client side controller if it exists.
  #
  # url - url to go to with optional params in uri format
  # options -
  #   :render_view - true if the view is being rendered
  #   :render_only - only render but don't call add_bindings on client controller
  #   :selector - the jquery selector to select the DOM element to render into
  #   :content_for - a hash with keys as the symbol for the content to be rendered (e.g. :footer) 
  #                  and the values as the selector of the DOM element to render into
  #
  def go_to_route(url, options={})
    #puts "go_to_route: url = #{url}"
    @current_route_action, @params = self.class.routes.match_url(url)
    #puts "before push_state"
    History.push_state({}, 'new route', url)
    #puts "go_to_route: action = #{@current_route_action.name}, params = #{@params}"
    @current_route_action.invoke_controller(@params, options)
    #puts "go_to_route: after invoke_controller"
  end

  def render_route(url, options={})
    route_action, params = self.class.routes.match_url(url)

    route_action.invoke_controller(params, {render_only: true}.merge(options))
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
