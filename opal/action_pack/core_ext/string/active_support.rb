class String
  #  def underscore
  #   if RUBY_ENGINE == 'opal'
  #     `#{self}.replace(/([A-Z\d]+)([A-Z][a-z])/g, '$1_$2')
  #     .replace(/([a-z\d])([A-Z])/g, '$1_$2')
  #     .replace(/-/g, '_')
  #     .toLowerCase()`
  #   else
  #     # stolen (mostly) from Rails::Activesupport
  #     return self unless self =~ /[A-Z-]|::/
  #     word = self.to_s.gsub('::', '/')
  #     word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
  #     word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
  #     word.tr!("-", "_")
  #     word.downcase!
  #     word
  #   end
  # end
  #
  # def capitalize
  #   self[0..0].upcase + self[1..-1]
  # end
  #
  # def camelize
  #   self.split(/_/).map{|s| s.capitalize}.join
  # end

  PLURALS = {
    "person" =>   "people",
    "resource" => "resources",
    "process" => "processes",
    "score" => "scores",
    "course" => "courses",
    "hole" => "holes"
  }
  INVERSE_PLURALS = PLURALS.invert

  # def singularize
  #   s = translate_final_segment(INVERSE_PLURALS)
  #   return s if s
  #   if m = /^(.*)es$/.match(self)
  #     m[1]
  #   elsif m = /^(.*)s$/.match(self)
  #     m[1]
  #   else
  #     self
  #   end
  # end

  # def pluralize
  #   s = translate_final_segment(PLURALS)
  #   return s if s
  #   if m = /^(.*)es$/.match(self)
  #     self
  #   elsif m = /^(.*)s$/.match(self)
  #     self
  #   else
  #     self + 's'
  #   end
  # end

  # def translate_final_segment(hash)
  #   segments = self.split(/_/)
  #
  #   if s = hash[segments.last]
  #     if segments.size > 1
  #       s = (segments[0..-2] + [s]).join("_")
  #     end
  #     s
  #   else
  #     nil
  #   end
  # end

  # OPAL-CHG-4: implement
  def html_safe
    self
  end
end

