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

describe ActionView do
  before do
    Application.reset
    Application.routes.draw do |router|
      resources :calculators
      resources :results
    end
  end

  describe "#render" do
    let(:template) { double('template') }

    before do
      @controller = CalculatorsController.new
    end

    it "renders from files" do
      action_view = ActionView::Renderer.new(@controller)
      expect(template).to receive(:render).with(action_view)
      expect(Template).to receive(:[]).with("a/b/c").and_return(template)
      action_view.render(file: "a/b/c")

      expect(action_view.instance_variable_get(:@ivar)).to eq(1)
    end

    context "when doing a partial" do
      it "renders from single-directory path partials" do
        action_view = ActionView::Renderer.new(@controller, path: "a/b/c")
        # it returns a new renderer
        #expect(template).to receive(:render).with(action_view)
        expect(template).to receive(:render)
        expect(Template).to receive(:[]).with("a/b/_d").and_return(template)
        action_view.render(partial: "d")
      end

      it "renders from multi-directory path partials" do
        action_view = ActionView::Renderer.new(@controller)
        # it returns a new renderer
        #expect(template).to receive(:render).with(action_view)
        expect(template).to receive(:render)
        expect(Template).to receive(:[]).with("a/b/_c").and_return(template)
        action_view.render(partial: "a/b/c")
      end
    end

    it "renders from text" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.render(text: "hello")).to eq("hello")
    end
  end

  describe "#link_to" do
    # it should generate an anchor link with and without options
  end

  describe "#resolve_path" do
    it "should match a show path" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.resolve_path('calculator', "1")).to eq("/calculators/1")
    end
  end

  describe "#method_missing" do
    it "should handle show _path method" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.calculator_path("1")).to eq("/calculators/1")
    end

    it "should handle show _path method with params" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.calculator_path("1", extra: 1)).to eq("/calculators/1?extra=1")
    end

    it "should handle a non-show member _path method" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.edit_calculator_path("1")).to eq("/calculators/1/edit")
    end

    it "should handle a index _path method" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.calculators_path).to eq("/calculators")
    end

    it "should handle a index _path method with params" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.calculators_path(extra: 1)).to eq("/calculators?extra=1")
    end

    it "should handle a non-index collection _path method" do
      action_view = ActionView::Renderer.new(@controller)
      expect(action_view.new_calculator_path).to eq("/calculators/new")
    end

    it "should handle references to locals" do
      action_view = ActionView::Renderer.new(@controller, locals: { test_var: 1})
      expect(action_view.test_var).to eq(1)
    end
  end
end

