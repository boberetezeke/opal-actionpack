require 'spec_helper'

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
