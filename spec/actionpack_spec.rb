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


if RUBY_ENGINE != "opal"
  class Template
  end
end

describe Application do
  let(:object1) { double('object') }

  describe "#launch" do
    before do
      Application.routes.draw do |router|
        router.resources :calculators
        router.resources :results
      end
       allow(object1).to receive(:save).and_return(nil)
    end

    context "when launching the application with a show action" do
      it "should be true" do
=begin
        show_controller = double('calculator_show_controller')
        expect(CalculatorsController).to receive(:new).with({id: '1'}).and_return(show_controller)
        expect(show_controller).to receive(:add_bindings)
        application = Application.instance.launch("/calculators/1", object1)
=end
      end
    end
  end

  describe Application::Action do
    describe "#match_path" do
      let(:route) { double('route') }

      it "matches if a show path with 1 arg" do
        action = Application::Action.new(route, :member, 'show', {id: '.*'})
        expect(action.match_path(:show, '1')).to eq(["1", {}])
      end

      it "matches if a show path with 1 arg and params" do
        action = Application::Action.new(route, :member, 'show', {id: '.*'})
        expect(action.match_path(:show, '1', extra: 1)).to eq(["1", {extra: 1}])
      end

      it "matches if a non-show member path with 1 arg" do
        action = Application::Action.new(route, :member, 'edit', {id: '.*'})
        expect(action.match_path(:edit, '1')).to eq(["1/edit", {}])
      end

      it "matches if a index path with 0 args" do
        action = Application::Action.new(route, :collection, 'index', {id: '.*'})
        expect(action.match_path(:index)).to eq(["", {}])
      end

      it "matches if a index path with params as args" do
        action = Application::Action.new(route, :collection, 'index', {id: '.*'})
        expect(action.match_path(:index, extra: 1)).to eq(["", {extra: 1}])
      end

      it "matches if a non-index collection path with 0 args" do
        action = Application::Action.new(route, :collection, 'new', {id: '.*'})
        expect(action.match_path(:new)).to eq(["new", {}])
      end

      #it "raises an exception with a member path without 1 arg"
      #it "raises an exception with a collection path without 0 args"
    end
=begin
    # 
    # These tests need to be rethought and explained
    # Also, it should be match_url_parts instead of just match
    #
    describe "#match" do
      let(:route) { double('route') }

      it "matches a show url" do
        action = Application::Action.new(route, :member, :show, [{id: '.*'}])
        expect(action.match(["show"], {})).to be_true
      end

      it "doesn't match a new url" do
        action = Application::Action.new(route, :member, :show, [{id: "\d+"}])
        expect(action.match(["new"], {})).to be_false
      end
    end
=end

  end

  describe Application::Route do
    describe "#match_path" do
      it "matches a show path" do
        route = Application::Route.new("calculators", {})
        expect(route.match_path("calculators", "show", "1")).to eq("/calculators/1")
      end

      it "matches a non-show member path" do
        route = Application::Route.new("calculators", {})
        expect(route.match_path("calculators", "edit", "1")).to eq("/calculators/1/edit")
      end

      it "matches an index path" do
        route = Application::Route.new("calculators", {})
        expect(route.match_path("calculators", "index")).to eq("/calculators")
      end

      it "matches an non-index collection path" do
        route = Application::Route.new("calculators", {})
        expect(route.match_path("calculators", "new")).to eq("/calculators/new")
      end

      #describe "#match"

    end
  end

  describe Application::Router do
    before do
      Application.routes.draw do |router|
        router.resources :calculators
        router.resources :results
      end
    end

    describe "#match_path" do
      it "matches a show path" do
        expect(Application.routes.match_path("calculators", "show", "1")).to eq("/calculators/1")
      end

      it "matches a non-show member path" do
        expect(Application.routes.match_path("results", "edit", "1")).to eq("/results/1/edit")
      end

      it "matches an index path" do
        expect(Application.routes.match_path("results", "index")).to eq("/results")
      end

      it "matches an non-index collection path" do
        expect(Application.routes.match_path("calculators", "new")).to eq("/calculators/new")
      end
    end

    #describe "#draw"
    #describe "#resources"
    #describe "#match_url"
    #describe "#to_parts"
  end
end

describe ActionView do
  before do
    Application.routes.draw do |router|
      router.resources :calculators
      router.resources :results
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
      expect(action_view.new_calculators_path).to eq("/calculators/new")
    end

    it "should handle references to locals" do
      action_view = ActionView::Renderer.new(@controller, locals: { test_var: 1})
      expect(action_view.test_var).to eq(1)
    end
  end
end
 
describe ActionController::Base do
  before do
    Application.routes.draw do |router|
      router.resources :calculators
      router.resources :results
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
