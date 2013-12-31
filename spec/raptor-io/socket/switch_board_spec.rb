require 'spec_helper'

require 'raptor-io/socket'

describe RaptorIO::Socket::SwitchBoard do
  subject(:switch_board) do
    described_class.new
  end

  it { should be_an Enumerable }

  describe "#add_route" do
    it "should add a route" do
      switch_board.routes.should be_empty
      switch_board.add_route("1.2.3.4", "255.255.255.0", nil)
      switch_board.routes.length.should == 1
    end
    it "should accept IPAddrs" do
      switch_board.routes.should be_empty
      switch_board.add_route(IPAddr.new("1.2.3.4"), IPAddr.new("255.255.255.0"), nil)
      switch_board.routes.length.should == 1
    end
  end

  describe "#each" do
    subject(:switch_board) do
      sb = described_class.new
      4.times do |i|
        sb.add_route("#{i}.2.3.4", "255.255.255.0", nil)
      end
      sb
    end

    it "should return all routes" do
      routes = []
      switch_board.each do |r|
        routes << r
      end
      routes.length.should == 4
      routes.should == switch_board.routes
    end
  end

  describe "#flush_routes" do
    it "should empty the routes" do
      switch_board.routes.should be_empty
      switch_board.add_route("1.1.1.1", "255.255.255.0", nil)
      switch_board.add_route("2.2.2.2", "255.255.255.0", nil)
      switch_board.routes.should_not be_empty
      switch_board.flush_routes
      switch_board.routes.should be_empty
    end
  end

  describe "#remove_route" do

  end

  describe "#best_comm" do
    it "should return the comm for the most specific route" do
      comm0 = double("more specific")
      comm1 = double("less specific")
      comm2 = double("even less specific")
      comm3 = double("different net")

      switch_board.add_route("1.1.1.0", "255.255.255.0", comm0)
      switch_board.add_route("1.1.0.0", "255.255.0.0", comm1)
      switch_board.add_route("1.0.0.0", "255.0.0.0", comm2)
      switch_board.add_route("2.2.2.0", "255.255.255.255", comm3)

      switch_board.best_comm("1.1.1.1").should == comm0
    end

    it "should fall back to less specific routes" do
      comm0 = double("more specific")
      comm1 = double("less specific")
      comm2 = double("different net")

      switch_board.add_route("1.1.1.0", "255.255.255.0", comm0)
      switch_board.add_route("1.1.0.0", "255.255.0.0", comm1)

      switch_board.best_comm("1.1.2.1").should == comm1

    end
  end

end
