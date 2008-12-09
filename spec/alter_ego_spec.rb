require 'ostruct'
require File.expand_path('spec_helper', File.dirname(__FILE__))

# let's define a traffic light class with three states: proceed, caution, and
# stop.  We'll leave the DSL for later, and use old-school class definitions to
# start out.

class TrafficLightWithClassicStates
  include AlterEgo

  class ProceedState < State
  end

  class CautionState < State
  end

  class StopState < State
  end

  add_state(ProceedState)
  add_state(CautionState)
  add_state(StopState)

end

describe TrafficLightWithClassicStates do
  before :each do
    @it = TrafficLightWithClassicStates
  end

  it "should have the specified states" do
    @it.states.values.should include(TrafficLightWithClassicStates::ProceedState)
    @it.states.values.should include(TrafficLightWithClassicStates::CautionState)
    @it.states.values.should include(TrafficLightWithClassicStates::StopState)
  end
end

# Before we go any further, we'll define some identifiers for our states.  This
# will make them easier to work with.

class TrafficLightWithIdentifiers
  include AlterEgo

  class ProceedState < State
    def self.identifier; :proceed; end
  end

  class CautionState < State
    def self.identifier; :caution; end
  end

  class StopState < State
    def self.identifier; :stop; end
  end

  add_state(ProceedState)
  add_state(CautionState)
  add_state(StopState)

  def initialize(starting_state = :proceed)
    self.state=(starting_state)
  end

  def cycle
    case current_state.identifier
    when :proceed then transition_to(:caution)
    when :caution then transition_to(:stop)
    when :stop    then transition_to(:proceed)
    else raise "Should never get here"
    end
  end
end

describe "a green light", :shared => true do
  it "should be in 'proceed' state" do
    @it.current_state.should == :proceed
  end

  it "should change to the caution (yellow) state on cycle" do
    @it.cycle
    @it.current_state.should == :caution
  end
end

describe "a yellow light", :shared => true do
  it "should be in 'caution' state" do
    @it.current_state.should == :caution
  end

  it "should change to stop (red) on cycle" do
    @it.cycle
    @it.current_state.should == :stop
  end
end

describe "a red light", :shared => true do
  it "should be in 'stop' state" do
    @it.current_state.should == :stop
  end

  it "should change to proceed (green) on cycle" do
    @it.cycle
    @it.current_state.should == :proceed
  end
end

describe TrafficLightWithIdentifiers, "by default" do
  before :each do
    @it = TrafficLightWithIdentifiers.new
  end

  it_should_behave_like "a green light"
end

describe TrafficLightWithIdentifiers, "when yellow" do
  before :each do
    @it = TrafficLightWithIdentifiers.new(:caution)
  end

  it_should_behave_like "a yellow light"
end

describe TrafficLightWithIdentifiers, "when red" do
  before :each do
    @it = TrafficLightWithIdentifiers.new(:stop)
  end

  it_should_behave_like "a red light"
end

# Being able to go from one state to another isn't that big a deal.  Let's add
# some state-specific behaviour.

class TrafficLightWithColors
  include AlterEgo

  class ProceedState < State
    def self.identifier
      :proceed
    end
    def color(traffic_light)
      "green"
    end
  end

  class CautionState < State
    def self.identifier
      :caution
    end
    def color(traffic_light)
      "yellow"
    end
  end

  class StopState < State
    def self.identifier
      :stop
    end
    def color(traffic_light)
      "red"
    end
  end

  add_state(ProceedState)
  add_state(CautionState)
  add_state(StopState)

  def initialize(starting_state = :proceed)
    self.state=(starting_state)
  end

  def cycle
    case current_state.identifier
    when :proceed then transition_to(:caution)
    when :caution then transition_to(:stop)
    when :stop    then transition_to(:proceed)
    else raise "Should never get here"
    end
  end
end

describe "a green light with color", :shared => true do
  it_should_behave_like "a green light"
  it "should have color green" do
    @it.color.should == "green"
  end
end

describe "a yellow light with color", :shared => true do
  it_should_behave_like "a yellow light"
  it "should have color yellow" do
    @it.color.should == "yellow"
  end
end

describe "a red light with color", :shared => true do
  it_should_behave_like "a red light"
  it "should have color red" do
    @it.color.should == "red"
  end
end

describe TrafficLightWithColors, "when green" do
  before :each do
    @it = TrafficLightWithColors.new(:proceed)
  end
  it_should_behave_like "a green light with color"
end

describe TrafficLightWithColors, "when yellow" do
  before :each do
    @it = TrafficLightWithColors.new(:caution)
  end
  it_should_behave_like "a yellow light with color"
end

describe TrafficLightWithColors, "when red" do
  before :each do
    @it = TrafficLightWithColors.new(:stop)
  end
  it_should_behave_like "a red light with color"
end

# This is all very verbose.  Now that we have a feel for the object model, let's
# introduce the DSL syntax.  Notice that the identifier becomes an argument to
# the 'state' declaration, and the #color methods become "handlers". Also note
# there is no longer any need for an explicit #add_state call.

class TrafficLightDescribedByDsl
  include AlterEgo

  state :proceed do
    handle :color do
      "green"
    end
  end

  state :caution do
    handle :color do
      "yellow"
    end
  end

  state :stop do
    handle :color do
      "red"
    end
  end

  def initialize(starting_state = :proceed)
    self.state=(starting_state)
  end

  def cycle
    case current_state.identifier
    when :proceed then transition_to(:caution)
    when :caution then transition_to(:stop)
    when :stop    then transition_to(:proceed)
    else raise "Should never get here"
    end
  end
end

describe TrafficLightDescribedByDsl, "when green" do
  before :each do
    @it = TrafficLightDescribedByDsl.new(:proceed)
  end

  it_should_behave_like "a green light with color"
end

describe TrafficLightDescribedByDsl, "when yellow" do
  before :each do
    @it = TrafficLightDescribedByDsl.new(:caution)
  end

  it_should_behave_like "a yellow light with color"
end

describe TrafficLightDescribedByDsl, "when red" do
  before :each do
    @it = TrafficLightDescribedByDsl.new(:stop)
  end

  it_should_behave_like "a red light with color"
end

# Let's redefine #cycle to be just another handler.  Note that when defined
# with the 'handler' syntax, handler blocks are executed in the context of the
# context object, that is, the object which has a state.

class TrafficLightWithCycleHandler
  include AlterEgo

  state :proceed do
    handle :color do
      "green"
    end
    handle :cycle do
      transition_to(:caution)
    end
  end

  state :caution do
    handle :color do
      "yellow"
    end
    handle :cycle do
      transition_to(:stop)
    end
  end

  state :stop do
    handle :color do
      "red"
    end
    handle :cycle do
      transition_to(:proceed)
    end
  end

  def initialize(starting_state = :proceed)
    self.state=(starting_state)
  end
end

describe TrafficLightWithCycleHandler, "when green" do
  before :each do
    @it = TrafficLightWithCycleHandler.new(:proceed)
  end

  it_should_behave_like "a green light with color"
end

describe TrafficLightWithCycleHandler, "when yellow" do
  before :each do
    @it = TrafficLightWithCycleHandler.new(:caution)
  end

  it_should_behave_like "a yellow light with color"
end

describe TrafficLightWithCycleHandler, "when red" do
  before :each do
    @it = TrafficLightWithCycleHandler.new(:stop)
  end

  it_should_behave_like "a red light with color"
end

# In fact, the pattern of a handler which executes a state transition is common
# enough that there is a special syntax for it. Let's convert to using that
# syntax.

# While we're at it, we'll also add a :default keyword to the :green state, and
# eliminate the initializer.

class TrafficLightWithTransitions
  include AlterEgo

  state :proceed, :default => true do
    handle :color do
      "green"
    end
    transition :to => :caution, :on => :cycle
  end

  state :caution do
    handle :color do
      "yellow"
    end
    transition :to => :stop, :on => :cycle
  end

  state :stop do
    handle :color do
      "red"
    end
    transition :to => :proceed, :on => :cycle
  end
end

describe TrafficLightWithTransitions, "by default" do
  before :each do
    @it = TrafficLightWithTransitions.new
  end

  it "should be in the green state" do
    @it.current_state.should == :proceed
  end
end

describe TrafficLightWithTransitions, "when green" do
  before :each do
    @it = TrafficLightWithTransitions.new
  end

  it_should_behave_like "a green light with color"
end

describe TrafficLightWithTransitions, "when yellow" do
  before :each do
    @it = TrafficLightWithTransitions.new
    @it.cycle
  end

  it_should_behave_like "a yellow light with color"
end

describe TrafficLightWithTransitions, "when red" do
  before :each do
    @it = TrafficLightWithTransitions.new
    @it.cycle
    @it.cycle
  end

  it_should_behave_like "a red light with color"
end

# It is possible to have only some of the states handle a given request.  If the
# method is called while the object is in a state which doesn't handle it, a
# WrongStateError will be raised.
#
# Let's add a #seconds_till_red method to our traffic light, so that it can show
# a countdown letting motorists know exactly how long they have until the light
# turns red.  Let's say for the sake of example that it will only be valid to
# call this method when the light is yellow.

class TrafficLightWithRedCountdown
  include AlterEgo

  state :proceed, :default => true do
    handle :color do
      "green"
    end
    transition :to => :caution, :on => :cycle
  end

  state :caution do
    handle :color do
      "yellow"
    end
    handle :seconds_till_red do
      # ...
    end
    transition :to => :stop, :on => :cycle
  end

  state :stop do
    handle :color do
      "red"
    end
    transition :to => :proceed, :on => :cycle
  end
end

describe TrafficLightWithRedCountdown, "that is green" do
  before :each do
    @it = TrafficLightWithRedCountdown.new
  end

  it "should raise an error if #seconds_till_red is called" do
    lambda do
      @it.seconds_till_red
    end.should raise_error(AlterEgo::WrongStateError)
  end
end

describe TrafficLightWithRedCountdown, "that is yellow" do
  before :each do
    @it = TrafficLightWithRedCountdown.new
    @it.cycle
  end

  it "should not raise an error when #seconds_till_red is called" do
    lambda do
      @it.seconds_till_red
    end.should_not raise_error
  end
end

# It is possible to get a list of currently handled requests, as well as a list
# of all possible requests supported in any state.

describe TrafficLightWithRedCountdown do
  before :each do
    @it = TrafficLightWithRedCountdown.new
  end

  it "should know what requests are supported by states" do
    @it.all_handled_requests.should include(:cycle, :color, :seconds_till_red)
  end
end

# The customer has decided the traffic light must sound an audible alert
# while in the yellow state, in order to warn vision-impaired pedestrians.
#
# In order to accomodate this requirement, we will use on_enter and on_exit
# handlers to switch an alarm on and off.

class TrafficLightWithAlarm
  include AlterEgo

  state :proceed, :default => true do
    handle :color do
      "green"
    end
    transition :to => :caution, :on => :cycle
  end

  state :caution do
    on_enter do
      turn_on_alarm
    end
    on_exit do
      turn_off_alarm
    end
    handle :color do
      "yellow"
    end
    handle :seconds_till_red do
      # ...
    end
    transition :to => :stop, :on => :cycle
  end

  state :stop do
    handle :color do
      "red"
    end
    transition :to => :proceed, :on => :cycle
  end

  def initialize(hardware_controller)
    @hardware_controller = hardware_controller
  end

  def turn_on_alarm
    @hardware_controller.alarm_enabled = true
  end

  def turn_off_alarm
    @hardware_controller.alarm_enabled = false
  end
end

describe TrafficLightWithAlarm do
  it "should not include on_enter or on_exit in list of handlers" do
    TrafficLightWithAlarm.all_handled_requests.should_not include(:on_enter)
    TrafficLightWithAlarm.all_handled_requests.should_not include(:on_exit)
  end
end

describe TrafficLightWithAlarm, "when green" do
  before :each do
    @hardware_controller = mock("Hardware Controller")
    @it = TrafficLightWithAlarm.new(@hardware_controller)
  end

  it "should enable alarm on transition to yellow" do
    @hardware_controller.should_receive(:alarm_enabled=).
      with(true)
    @it.cycle
  end
end

describe TrafficLightWithAlarm, "when yellow" do
  before :each do
    @hardware_controller = stub("Hardware Controller", :alarm_enabled= => nil)
    @it = TrafficLightWithAlarm.new(@hardware_controller)
    @it.cycle
  end

  it "should disable alarm on transition to yellow" do
    @hardware_controller.should_receive(:alarm_enabled=).
      with(false)
    @it.cycle
  end
end

# For safety reasons, the light should not allow transitions faster than every
# twenty seconds.  We'll add state guards to ensure this constraint is observed.
# We'll also add a generic state change action for all states to restart the timer
# each time the state changes.

class TrafficLightWithGuards
  include AlterEgo

  state :proceed, :default => true do
    handle :color do
      "green"
    end
    transition :to => :caution, :on => :cycle, :if => :min_time_elapsed?
  end

  state :caution do
    on_enter do
      turn_on_alarm
    end
    on_exit do
      turn_off_alarm
    end
    handle :color do
      "yellow"
    end
    handle :seconds_till_red do
      # ...
    end
    transition :to => :stop, :on => :cycle, :if => :min_time_elapsed?
  end

  state :stop do
    handle :color do
      "red"
    end

    # Just to demonstrate that it is possible, we use a proc here instead of a
    # symbol
    transition(:to => :proceed, :on => :cycle, :if => proc { min_time_elapsed? })
  end

  # On state change
  request_filter :state => any, :request => any, :new_state => not_nil do
    @hardware_controller.restart_timer
  end

  def initialize(hardware_controller)
    @hardware_controller = hardware_controller
  end

  def turn_on_alarm
    @hardware_controller.alarm_enabled = true
  end

  def turn_off_alarm
    @hardware_controller.alarm_enabled = false
  end

  def min_time_elapsed?
    @hardware_controller.time_elapsed >= 20
  end
end

describe TrafficLightWithGuards, "that is green" do
  before :each do
    @hardware_controller = stub("Hardware Controller",
                                :time_elapsed   => 21,
                                :restart_timer  => nil,
                                :alarm_enabled= => nil)
    @it = TrafficLightWithGuards.new(@hardware_controller)
  end

  it "should check the hardware controller's #time_elapsed on cycle"   do
    @hardware_controller.should_receive(:time_elapsed).and_return(19)
    @it.cycle
  end

  it "should fail to cycle if elapsed time < 20 seconds" do
    @hardware_controller.stub!(:time_elapsed).and_return(19)
    @it.cycle.should be_false
    @it.current_state.should == :proceed
  end

  it "should cycle if elapsed time >= 20 seconds" do
    @hardware_controller.stub!(:time_elapsed).and_return(20)
    @it.cycle.should be_true
    @it.current_state.should == :caution
  end

  it "should restart the timer on state change" do
    @hardware_controller.should_receive(:restart_timer)
    @it.cycle
  end

  it "should restart the timer on state change" do
    @hardware_controller.should_receive(:restart_timer)
    @it.cycle
  end
end

describe TrafficLightWithGuards, "that is yellow" do
  before :each do
    @hardware_controller = stub("Hardware Controller",
                                :time_elapsed   => 21,
                                :restart_timer  => nil,
                                :alarm_enabled= => nil)
    @it = TrafficLightWithGuards.new(@hardware_controller)
    @it.cycle
  end

  it "should check the hardware controller's #time_elapsed on cycle"   do
    @hardware_controller.should_receive(:time_elapsed).and_return(19)
    @it.cycle
  end

  it "should fail to cycle if elapsed time < 20 seconds" do
    @hardware_controller.stub!(:time_elapsed).and_return(19)
    @it.cycle.should be_false
  end

  it "should remain in :caution state if elapsed time < 20" do
    @hardware_controller.stub!(:time_elapsed).and_return(19)
    @it.cycle
    @it.current_state.should == :caution
  end

  it "should cycle if elapsed time >= 20 seconds" do
    @hardware_controller.stub!(:time_elapsed).and_return(20)
    @it.cycle.should be_true
  end

  it "should cycle to :stop state if elapsed time >= 20 seconds" do
    @hardware_controller.stub!(:time_elapsed).and_return(20)
    @it.cycle
    @it.current_state.should == :stop
  end

  it "should restart the timer on state change" do

    @hardware_controller.should_receive(:restart_timer)
    @it.cycle
  end
end

describe TrafficLightWithGuards, "that is red" do
  before :each do
    @hardware_controller = stub("Hardware Controller",
                                :time_elapsed   => 21,
                                :restart_timer  => nil,
                                :alarm_enabled= => nil)
    @it = TrafficLightWithGuards.new(@hardware_controller)
    @it.cycle
    @it.cycle
  end

  it "should fail to cycle if elapsed time < 20 seconds" do
    @hardware_controller.stub!(:time_elapsed).and_return(19)
    @it.cycle.should be_false
    @it.current_state.should == :stop
  end

  it "should cycle if elapsed time >= 20 seconds" do
    @hardware_controller.stub!(:time_elapsed).and_return(20)
    @it.cycle.should be_true
    @it.current_state.should == :proceed
  end

end

# The traffic light controller actually stores it's current state as three
# discrete booleans, one for each light which should be either on or off.  We'll
# customize the state saving and loading methods in order to support this
# arrangement.

class TrafficLightWithCustomStorage
  include AlterEgo

  state :proceed, :default => true do
    handle :color do
      "green"
    end
    transition :to => :caution, :on => :cycle
  end

  state :caution do
    on_enter do
      turn_on_alarm
    end
    on_exit do
      turn_off_alarm
    end
    handle :color do
      "yellow"
    end
    handle :seconds_till_red do
      # ...
    end
    transition :to => :stop, :on => :cycle
  end

  state :stop do
    handle :color do
      "red"
    end
    transition :to => :proceed, :on => :cycle
  end

  def initialize(hardware_controller)
    @hardware_controller = hardware_controller
  end

  def turn_on_alarm
    @hardware_controller.alarm_enabled = true
  end

  def turn_off_alarm
    @hardware_controller.alarm_enabled = false
  end

  def state
    gyr = [
      @hardware_controller.green,
      @hardware_controller.yellow,
      @hardware_controller.red
    ]

    case gyr
    when [true, false, false] then :proceed
    when [false, true, false] then :caution
    when [false, false, true] then :stop
    else raise "Invalid state!"
    end
  end

  def state=(value)
    gyr = case value
          when :proceed  then [true, false, false]
          when :caution  then [false, true, false]
          when :stop     then [false, false, true]
          end
    @hardware_controller.green  = gyr[0]
    @hardware_controller.yellow = gyr[1]
    @hardware_controller.red    = gyr[2]
  end
end


describe TrafficLightWithCustomStorage, "that is green" do
  before :each do
    @hardware_controller = OpenStruct.new( :time_elapsed   => 21,
                                           :restart_timer  => nil,
                                           :green          => true,
                                           :yellow         => false,
                                           :red            => false)
    @it = TrafficLightWithCustomStorage.new(@hardware_controller)
  end

  it "should be in the proceed state" do
    @it.current_state.should == :proceed
  end

  it "should set lights for yellow on cycle" do
    @it.cycle
    @hardware_controller.green.should be_false
    @hardware_controller.yellow.should be_true
    @hardware_controller.red.should be_false
  end
end

describe TrafficLightWithCustomStorage, "that is yellow" do
  before :each do
    @hardware_controller = OpenStruct.new( :time_elapsed   => 21,
                                           :restart_timer  => nil,
                                           :green          => false,
                                           :yellow         => true,
                                           :red            => false)
    @it = TrafficLightWithCustomStorage.new(@hardware_controller)
  end

  it "should be in the caution state" do
    @it.current_state.should == :caution
  end

  it "should set lights for red on cycle" do
    @it.cycle
    @hardware_controller.green.should be_false
    @hardware_controller.yellow.should be_false
    @hardware_controller.red.should be_true
  end

end

describe TrafficLightWithCustomStorage, "that is red" do
  before :each do
    @hardware_controller = OpenStruct.new( :time_elapsed   => 21,
                                           :restart_timer  => nil,
                                           :green          => false,
                                           :yellow         => false,
                                           :red            => true)
    @it = TrafficLightWithCustomStorage.new(@hardware_controller)
  end

  it "should be in the stop state" do
    @it.current_state.should == :stop
  end

  it "should set lights for green on cycle" do
    @it.cycle
    @hardware_controller.green.should be_true
    @hardware_controller.yellow.should be_false
    @hardware_controller.red.should be_false
  end

end

# In order to integrate with a pedestrian traffic light, our light needs to send
# a signal whenever it changes.  We'll add a transition action to handle this.
#
# It also needs to flash a strobe when transitioning to yellow or red.  We'll
# use a request filter and a state matching pattern to accomplish this.

class TrafficLightWithTransAction
  include AlterEgo

  state :proceed, :default => true do
    handle :color do
      "green"
    end
    transition :to => :caution, :on => :cycle do
      @hardware_controller.notify(:yellow)
    end
  end

  state :caution do
    on_enter do
      turn_on_alarm
    end
    on_exit do
      turn_off_alarm
    end
    handle :color do
      "yellow"
    end
    handle :seconds_till_red do
      # ...
    end
    transition :to => :stop, :on => :cycle do
      @hardware_controller.notify(:red)
    end
  end

  state :stop do
    handle :color do
      "red"
    end
    transition :to => :proceed, :on => :cycle do
      @hardware_controller.notify(:green)
    end
  end

  request_filter :state     => any,
                 :request   => any,
                 :new_state => [:caution, :stop] do
    @hardware_controller.flash_strobe
  end

  def initialize(hardware_controller)
    @hardware_controller = hardware_controller
  end

  def turn_on_alarm
    @hardware_controller.alarm_enabled = true
  end

  def turn_off_alarm
    @hardware_controller.alarm_enabled = false
  end

  def state
    gyr = [
      @hardware_controller.green,
      @hardware_controller.yellow,
      @hardware_controller.red
    ]

    case gyr
    when [true, false, false] then :proceed
    when [false, true, false] then :caution
    when [false, false, true] then :stop
    else raise "Invalid state!"
    end
  end

  def state=(value)
    gyr = case value
          when :proceed  then [true, false, false]
          when :caution  then [false, true, false]
          when :stop     then [false, false, true]
          end
    @hardware_controller.green  = gyr[0]
    @hardware_controller.yellow = gyr[1]
    @hardware_controller.red    = gyr[2]
  end
end

describe TrafficLightWithTransAction, "that is green" do
  before :each do
    @hardware_controller = OpenStruct.new( :time_elapsed   => 21,
                                           :restart_timer  => nil,
                                           :green          => true,
                                           :yellow         => false,
                                           :red            => false)
    @hardware_controller.stub!(:notify)
    @it = TrafficLightWithTransAction.new(@hardware_controller)
  end

  it "should notify that it has turned yellow on cycle" do
    @hardware_controller.should_receive(:notify).with(:yellow)
    @it.cycle
  end

  it "should flash strobe on cycle to yellow" do
    @hardware_controller.should_receive(:flash_strobe)
    @it.cycle
  end
end


describe TrafficLightWithTransAction, "that is yellow" do
  before :each do
    @hardware_controller = OpenStruct.new( :time_elapsed   => 21,
                                           :restart_timer  => nil,
                                           :green          => false,
                                           :yellow         => true,
                                           :red            => false)
    @hardware_controller.stub!(:notify)
    @it = TrafficLightWithTransAction.new(@hardware_controller)
  end

  it "should notify that it has turned red on cycle" do
    @hardware_controller.should_receive(:notify).with(:red)
    @it.cycle
  end

  it "should flash strobe on cycle to red" do
    @hardware_controller.should_receive(:flash_strobe)
    @it.cycle
  end
end

describe TrafficLightWithTransAction, "that is red" do
  before :each do
    @hardware_controller = OpenStruct.new( :time_elapsed   => 21,
                                           :restart_timer  => nil,
                                           :green          => false,
                                           :yellow         => false,
                                           :red            => true)
    @hardware_controller.stub!(:notify)
    @it = TrafficLightWithTransAction.new(@hardware_controller)
  end

  it "should notify that it has turned green on cycle" do
    @hardware_controller.should_receive(:notify).with(:green)
    @it.cycle
  end

  it "should not flash strobe on cycle to green" do
    @hardware_controller.should_not_receive(:flash_strobe)
  end

end
