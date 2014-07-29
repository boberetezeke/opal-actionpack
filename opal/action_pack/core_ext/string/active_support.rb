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
end

