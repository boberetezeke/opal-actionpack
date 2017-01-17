require 'spec_helper'

describe Application::Router do
  before do
    Application.routes.draw do |router|
      resources :calculators
      resources :results
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
