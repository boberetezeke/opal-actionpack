module UrlHelper
  # OPAL-CHG-3 - need to implement all/most of UrlHelper
  def url_for(url_for_options)
    # FIXME: need to implement
    url_for_options
  end

  def link_to(text, path, options={})
    #puts "path = #{path}, options=#{options}"
    "<a href=\"#{path}\"" + options.map{|k,v| "#{k}=\"#{v}\""}.join(' ') + ">#{text}</a>"
    #"<a href=\"#{path}\">#{text}</a>"
    #"<a href=\"#\">#{text}</a>"
  end

  DEFAULT_POLYMORPHIC_PATH_OPTIONS = {format: :post}
  def polymorphic_path(record, options={})
    options = DEFAULT_POLYMORPHIC_PATH_OPTIONS.merge(options)
    #OPAL-CHG-2
    #Application.routes.match_path(record.class.to_s, options[:format], record.id)
    "/#{record.class.to_s.underscore.pluralize}/#{record.id}"
  end
end
