module PathHandler
  def resolve_path(root, *args)
    @application.resolve_path(root, *args)
  end

  def method_missing(sym, *args, &block)
    sym_to_s = sym.to_s
    m = /^(.*)_path$/.match(sym_to_s)
    if m
      return @application.resolve_path(m[1], *args)
    end

    super
  end
end
