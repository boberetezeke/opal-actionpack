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
