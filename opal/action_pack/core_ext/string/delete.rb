class String
  def delete(str)
    self.gsub(/#{Regexp.escape(str)}/, "")
  end
end
