#
# The application class holds the starting point for launching the client side application
#
# 
# 
class Application
  include SemanticLogger::Loggable

  #
  # return router for use in routes.rb
  #
  # @return [Router] - the router for the application
  #
  def self.routes
    @routes ||= Router.new
  end

  #
  # reset class variables for testing purposes
  #
  def self.reset
    @routes = nil
  end

  #
  # return the single instance of the application
  #
  # @return [Application] - the application object
  #
  def self.instance
    return @@application if defined?(@@application)
    @@application = new
    @@application
  end

  attr_reader :session, :current_path

  #
  # Initialize the application and establish connection to the local store
  #
  def initialize
    #puts "in initialize of class #{self.class.to_s}"

    @store = get_store
    ActiveRecord::Base.connection = @store
  end

  #
  # return if the app is starting from a call to launch
  # 
  # @return [Boolean] - true if the app is starting from launching
  #
  def app_starting?
    @launching
  end

  #
  # return the router
  # 
  # @return [Router] - the router for the application
  #
  def routes
    self.class.routes
  end

  protected
  
  #
  # return the store to use for the application, override this to provide your
  # own store. By default this returns an in memory store
  #
  # @return [ActiveRecord::Store] - the store for the application
  #
  def get_store
    ActiveRecord::MemoryStore.new
  end

  #
  # The name for the root path for the views inside of the opal path
  #
  # @return [String] - the views path root
  #
  def view_root
    "views"
  end
  
  public

  #
  # Start the application by launching it with a set of objects, session info and a block
  #
  # @param initial_objects_json [String] - json string for the application's starting data
  # @param session [Hash] - a hash of keys from the session
  # @param block [Proc`] - block to call just before going to the controller route
  #
  def launch(initial_objects_json, session={}, block=Proc.new)
    # logger.debug "block = #{block}"
    capture_exception do
      @launching = true
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
      @launching = false
    end
  end

  #
  # resolve a path to a url
  #
  # @param path [String] - the root of a path method name (i.e. without _path suffix)
  # @param args [Array] - extra arguments passed on to routes
  # @return [String] - the url specified by the given path
  #
  def resolve_path(path, *args)
    # logger.debug "resolve_path: #{path}, args = #{args}"
    m = /^(([^_]+)_)?((\w+?)?)$/.match(path)
    if m
      action_with_underscore = m[1]
      action = m[2]
      resource = m[3]

      # logger.debug "resolve_path: matched pattern: #{m}, action = #{action.inspect}, resource = #{resource}"

      return self.class.routes.match_path(resource, action, *args)
    else
      raise "unable to match path: #{path}_path"
    end
  end

  # 
  # Goes to the route specified as passes options on to invoke_controller
  #
  # Then it invokes the server side controller, optionally render's the view and then
  # invokes the client side controller if it exists.
  #
  # @param url [String] - url to go to with optional params in uri format
  # @param options [Hash] - hash of options
  #   :render_view - true if the view is being rendered
  #   :render_only - only render but don't call add_bindings on client controller
  #   :selector - the jquery selector to select the DOM element to render into
  #   :content_for - a hash with keys as the symbol for the content to be rendered (e.g. :footer) 
  #                  and the values as the selector of the DOM element to render into
  #   :push_history - true if push to browser history
  #   :keep_current_path - don't overwrite current path if true
  #
  # @return [Array<ApplicationController::Base, ApplicationController::Base>] - the server and client controllers created
  #
  def go_to_route(url, options={}, additional_params={})
    @after_render_block = nil
    @came_from_route = true
    # logger.debug "go_to_route: #{url}, options=#{options}, additional_params=#{additional_params}"
    @current_path = UrlParser.to_path(url) unless options[:keep_current_path]
    # puts "go_to_route: url = #{url}"
    current_route_action, @params = self.class.routes.match_url(url)
    # logger.debug "go_to_route: params = #{@params}"
    @params = @params.merge(additional_params)
    # logger.debug "go_to_route: params = #{@params} after additional_params added"
    # logger.debug "go_to_route: render is done: #{@came_from_route}"
    @controller = current_route_action.invoke_controller(@params, options)
    
    # puts "before push_state"
    if options[:push_history]
      History.push_state({}, 'new route', url)
    else
      History.replace_state({}, 'new route', url)
    end
    
    @controller
  end

  #
  # register a block to be called after rendering is done
  #
  # @param block [Proc] - the block to call after rendering is done
  #
  def after_render(&block)
    @after_render_block = block
  end
  
  #
  # return if the render was done after coming from a route
  #
  # @return [Boolean] - true if render was done in response to a go_to_route
  #
  def came_from_route
    @came_from_route
  end
  
  #
  # render is done
  #
  def render_is_done(did_render)
    # logger.debug "render is done: #{@came_from_route}"
    @after_render_block.call(did_render) if @after_render_block
    @came_from_route = false
  end
end
