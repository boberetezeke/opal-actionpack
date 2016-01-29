module UrlParser
  def self.to_path(url)
    if m = /^([^?]*)\?(.*)$/.match(url)
      m[1]
    else
      url
    end
  end

  def self.to_parts(url)
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

    # FIXME: opal does split diff than MRI
    if url == ""
      parts = []
    else
      parts =  url.split(/\//)
    end
    [parts, params]
  end

  def self.from_path_and_params(path, params)
    if params.empty?
      path
    else
      path + "?" + params.to_a.map{|key, value| "#{encodeURI(key)}=#{encodeURI(value)}" }.join("&")
    end
  end

  def self.encodeURI(str)
    `encodeURI(str)`
  end
end
