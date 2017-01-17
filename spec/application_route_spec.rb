require 'spec_helper'

describe Application::Route do
  describe "#match_path" do
    it "matches a show path" do
      route = Application::Route.new("calculators", false, {})
      expect(route.match_path("calculators", "show", "1")).to eq("/calculators/1")
    end

    it "matches a non-show member path" do
      route = Application::Route.new("calculators", false, {})
      expect(route.match_path("calculators", "edit", "1")).to eq("/calculators/1/edit")
    end

    it "matches an index path" do
      route = Application::Route.new("calculators", false, {})
      expect(route.match_path("calculators", "index")).to eq("/calculators")
    end

    it "matches an non-index collection path" do
      route = Application::Route.new("calculators", false, {})
      expect(route.match_path("calculators", "new")).to eq("/calculators/new")
    end

    #describe "#match"

  end
end
