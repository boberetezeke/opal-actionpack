require 'spec_helper'

# mock up ActiveRecord
class ActiveRecord
  class Base
    def self.connection=(connection)
    end
  end

  class MemoryStore
  end
end

class CalculatorsController < ActionController::Base
  def initialize(params={})
    super
    @ivar = 1
  end
end

class Nested
  class ResultsController < ActionController::Base
  end
end

class CalculatorsClientController
  class Show < ActionController::Base
    def initialize(params)
      super
    end

    def add_bindings
    end

    def invoke_callback
      calculators_path(id:1)
    end
  end
end

describe ActionController::Base do
  before do
    Application.routes.draw do |router|
      resources :calculators
      resources :results
    end
  end

  describe "#action_method" do
    it "should resolve_paths in the application" do
      expect(Application.instance).to receive(:resolve_path)
      calculators_controller = CalculatorsClientController::Show.new({})
      calculators_controller.invoke_callback
    end
  end

  describe "#view_path" do
    it "should return the path to the view on a sinple controller" do
      controller = CalculatorsController.new({})
      expect(controller.view_path).to eq("calculators")
    end

    it "should return the path to the view on a sinple controller" do
      controller = Nested::ResultsController.new({})
      expect(controller.view_path).to eq("nested/results")
    end
  end

  describe "#controller_root_name" do
    it "should return a downcased name fo the controller class's root name" do
      controller = CalculatorsController.new({})
      expect(controller.controller_root_name("CalculatorsController")).to eq("calculators")
    end
  end
end
