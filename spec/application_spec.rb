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

# if RUBY_ENGINE != "opal"
#   class Template
#   end
# end

describe Application do
  let(:object1) { double('object') }

  before do
    allow(object1).to receive(:save).and_return(nil)
    Application.reset
    Application.routes.draw do |router|
      resource :calculator do
        member do
          get :blue
        end
      end
      resources :results do
        member do
          get :frilly
        end
        collection do
          get :fancy
        end
      end
    end
  end

  describe "#launch" do
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

  describe "#resolve_path" do
    context "for singular routes" do
      it "handles show routes" do
        expect(Application.instance.resolve_path("calculator")).to eq("/calculator")
      end

      it "handles edit route" do
        expect(Application.instance.resolve_path("edit_calculator")).to eq("/calculator/edit")
      end

      it "handles custom member route" do
        expect(Application.instance.resolve_path("blue_calculator")).to eq("/calculator/blue")
      end
    end

    context "for plural routes" do

      # member routes

      it "handles show routes" do
        expect(Application.instance.resolve_path("result", 1)).to eq("/results/1")
      end

      it "handles edit route" do
        expect(Application.instance.resolve_path("edit_result", 1)).to eq("/results/1/edit")
      end

      it "handles custom member route" do
        expect(Application.instance.resolve_path("frilly_result", 1)).to eq("/results/1/frilly")
      end

      # collection routes

      it "handles index routes" do
        expect(Application.instance.resolve_path("results")).to eq("/results")
      end

      it "handles new route" do
        expect(Application.instance.resolve_path("new_result")).to eq("/results/new")
      end

      it "handles custom collection route" do
        expect(Application.instance.resolve_path("fancy_results")).to eq("/results/fancy")
      end
    end
  end
end

