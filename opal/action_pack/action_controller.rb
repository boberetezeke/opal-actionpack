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

    #
    # render a template 
    #
    # options: 
    #   :content_for - a hash with keys as the symbol for the content to be rendered (e.g. :footer) 
    #                  and the values as the selector of the DOM element to render into
    #   :partial - true if rendering a partial
    #
    def render_template(options={})
      puts "render_template(start)"
      `var d = new Date(); console.log("time= " + d.getSeconds() + ":" + d.getMilliseconds());`
      #Timer.time_stamp("render_template (begin)")
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
      puts "render_template(end)"
      `var d = new Date(); console.log("time= " + d.getSeconds() + ":" + d.getMilliseconds());`
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

    def render_route(*args, &block)
      @application.render_route(*args, &block)
    end
    #
    # bind to a DOM event
    #
    # This binds to a DOM event. It automatically unbinds on go_to_route.
    #
    # Example:
    #
    #   bind_event("#button", :click) do
    #     do_something
    #   end
    #
    # options:
    #   returns_propagation_result - if true, the result of the block determines
    #     if the event should propagate or not
    #
    def bind_event(selector, event, options={})
      @bound_events[selector] = BoundEvent.new(event, selector)
      Element.find(selector).on(event) do
        puts "bind_event: #{selector}: #{event}"
        propagate = false
        capture_exception do
          if options[:returns_propagation_result]
            propagate = yield
          else
            yield
          end
        end
        puts "bind_event: propagate = #{propagate}"
        propagate
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

