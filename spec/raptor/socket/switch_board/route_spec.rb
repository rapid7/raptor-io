require 'spec_helper'

require 'raptor/socket'

describe Raptor::Socket::SwitchBoard::Route do

  context "class methods" do
    describe ".new" do
      it "should accept an IPAddr for subnet and netmask" do
        expect {
          described_class.new(IPAddr.new("1.2.3.4"), IPAddr.new("255.255.0.0"), nil)
        }.not_to raise_error
      end
      it "should accept a String for subnet and netmask" do
        expect {
          described_class.new("1.2.3.4", "255.255.0.0", nil)
        }.not_to raise_error
      end
    end
  end

  context "instance methods" do
    subject(:route) do
      Raptor::Socket::SwitchBoard::Route.new("1.2.3.4", "255.255.255.0", nil)
    end

    describe "#==" do
      it "should be equal if attributes are the same" do
        Raptor::Socket::SwitchBoard::Route.new("1.2.3.4", "255.255.255.0", nil).should == route
      end
      it "should NOT be equal if any attributes are different" do
        Raptor::Socket::SwitchBoard::Route.new("1.2.3.4", "255.0.0.0", nil).should_not == route
        Raptor::Socket::SwitchBoard::Route.new("2.2.3.4", "255.255.255.0", nil).should_not == route
      end
    end

    describe "#<=>" do
      it "should compare the subnet" do
        other = Raptor::Socket::SwitchBoard::Route.new("0.0.0.0", "255.255.0.0", nil)
        (route.<=> other).should == 1
        other = Raptor::Socket::SwitchBoard::Route.new("0.0.0.0", "255.255.255.0", nil)
        (route.<=> other).should == 0
        other = Raptor::Socket::SwitchBoard::Route.new("0.0.0.0", "255.255.255.255", nil)
        (route.<=> other).should == -1
      end
    end
  end

end
