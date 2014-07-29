class String
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
  def present?
    !blank?
  end
end
