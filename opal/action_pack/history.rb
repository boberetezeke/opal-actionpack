class History
  def self.push_state(state_object, title, url)
    `window.history.pushState({}, title, url)`
  end

  def self.pop_state
    `window.history.back()`
  end

  def self.on_pop_state(&block)
    %x{
      self = this;
      window.onpopstate = function(event) {
        block();
      }
    }
  end
end
