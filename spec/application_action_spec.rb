require 'spec_helper'

describe Application::Action do
  describe "#match_path" do
    let(:route) { double('route') }

    it "matches if a show path with 1 arg" do
      action = Application::Action.new(route, :member, name: 'show', parts: {id: '.*'})
      expect(action.match_path(:show, '1')).to eq(["1", {}])
    end

    it "matches if a show path with 1 arg and params" do
      action = Application::Action.new(route, :member, name: 'show', parts: {id: '.*'})
      expect(action.match_path(:show, '1', extra: 1)).to eq(["1", {extra: 1}])
    end

    it "matches if a non-show member path with 1 arg" do
      action = Application::Action.new(route, :member, name: 'edit', parts: {id: '.*'})
      expect(action.match_path(:edit, '1')).to eq(["1/edit", {}])
    end

    it "matches if a index path with 0 args" do
      action = Application::Action.new(route, :collection, name: 'index', parts: {id: '.*'})
      expect(action.match_path(:index)).to eq(["", {}])
    end

    it "matches if a index path with params as args" do
      action = Application::Action.new(route, :collection, name: 'index', parts: {id: '.*'})
      expect(action.match_path(:index, extra: 1)).to eq(["", {extra: 1}])
    end

    it "matches if a non-index collection path with 0 args" do
      action = Application::Action.new(route, :collection, name: 'new', parts: {id: '.*'})
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

