require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::R6TopSuicideAgent do
  before(:each) do
    @valid_options = Agents::R6TopSuicideAgent.new.default_options
    @checker = Agents::R6TopSuicideAgent.new(:name => "R6TopSuicideAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
