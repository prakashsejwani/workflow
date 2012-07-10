require 'rubygems'

require 'workflow/specification'
require 'workflow/adapters/active_record'
require 'workflow/adapters/remodel'
require 'workflow/draw'

# See also README.markdown for documentation
module Workflow
  module ClassMethods
    attr_reader :workflow_spec

    def workflow_column(column_name=nil)
      if column_name
        @workflow_state_column_name = column_name.to_sym
      end
      if !@workflow_state_column_name && superclass.respond_to?(:workflow_column)
        @workflow_state_column_name = superclass.workflow_column
      end
      @workflow_state_column_name ||= :workflow_state
    end

    def workflow(&specification)
      @workflow_spec = Specification.new(Hash.new, &specification)
      @workflow_spec.states.values.each do |state|
        state_name = state.name
        module_eval do
          define_method "#{state_name}?" do
            state_name == current_state.name
          end
        end

        state.events.values.each do |event|
          event_name = event.name
          module_eval do
            define_method "#{event_name}!".to_sym do |*args|
              process_event!(event_name, *args)
            end

            define_method "can_#{event_name}?" do
              return self.has_event?(event_name)
            end
          end
        end
      end
    end
  end

  module InstanceMethods

    def current_state
      loaded_state = load_workflow_state
      res = spec.states[loaded_state.to_sym] if loaded_state
      res || spec.initial_state
    end

    # See the 'Guards' section in the README
    # @return true if the last transition was halted by one of the transition callbacks.
    def halted?
      @halted
    end

    # @return the reason of the last transition abort as set by the previous
    # call of `halt` or `halt!` method.
    def halted_because
      @halted_because
    end

    def process_event!(name, *args)
      event = current_state.events[name.to_sym]
      raise NoTransitionAllowed.new(
        "There is no event #{name.to_sym} defined for the #{current_state} state") \
        if event.nil?
      @halted_because = nil
      @halted = false
      @halted, @halted_because = halt_event?(name)
      return false if @halted
          
      check_transition(event)

      from = current_state
      to = spec.states[event.transitions_to]

      run_before_transition(from, to, name, *args)
      return false if @halted

      begin
        return_value = run_action(event.action, *args) || run_action_callback(event.name, *args)
      rescue Exception => e
        run_on_error(e, from, to, name, *args)
      end

      return false if @halted

      run_on_transition(from, to, name, *args)

      run_on_exit(from, to, name, *args)

      transition_value = persist_workflow_state to.to_s

      run_on_entry(to, from, name, *args)

      run_after_transition(from, to, name, *args)

      return_value.nil? ? transition_value : return_value
    end

    def halt(reason = nil)
      @halted_because = reason
      @halted = true
    end

    def halt!(reason = nil)
      @halted_because = reason
      @halted = true
      raise TransitionHalted.new(reason)
    end

    def spec
      # check the singleton class first
      class << self
        return workflow_spec if workflow_spec
      end

      c = self.class
      # using a simple loop instead of class_inheritable_accessor to avoid
      # dependency on Rails' ActiveSupport
      until c.workflow_spec || !(c.include? Workflow)
        c = c.superclass
      end
      c.workflow_spec
    end


    # checks whether the current state can move to the given event
    # calls the proc in event.condition to ascertain this.
    # returns an Array with [Boolean, String]
    def can_do_event?(event_name)
      msg = "event not allowed"
      p = false
      event = current_state.events[event_name]
      return [p, msg] unless event
      predicate = event.condition
      return [true, ""] unless predicate # no if condition given
      p, _msg = [predicate].flatten
      [p.call(self), _msg || msg]
    end

    # returns the opposite boolean value as can_do_event?
    def halt_event?(event_name)
      rv = can_do_event?(event_name)
      [!rv[0],rv[1]]
    end

    # returns only the Boolean value of can_do_event?
    def has_event?(event_name)
      can_do_event?(event_name)[0]
    end

    # Public: for use as an RSpec matcher
    #
    # es -> an Array of events
    # returns true if the object returns true for has_event? on each of the events
    def has_events?(es)
      !(es.map{|e| has_event?(e)}.include?(false))
    end
    
    # Public: for use as an RSpec matcher
    #
    # events -> an Array of events
    # returns true only if these are the only events possible in this state. i.e. if we leave out an event, it will return false
    def has_only_events?(es)
      Set.new(current_state.events.keys.select{|e| has_event?(e)}) == Set.new(es)
    end

    private


    def check_transition(event)
      # Create a meaningful error message instead of
      # "undefined method `on_entry' for nil:NilClass"
      # Reported by Kyle Burton
      if !spec.states[event.transitions_to]
        raise WorkflowError.new("Event[#{event.name}]'s " +
            "transitions_to[#{event.transitions_to}] is not a declared state.")
      end
    end

    def run_before_transition(from, to, event, *args)
      instance_exec(from.name, to.name, event, *args, &spec.before_transition_proc) if
        spec.before_transition_proc
    end

    def run_on_error(error, from, to, event, *args)
      if spec.on_error_proc
        instance_exec(error, from.name, to.name, event, *args, &spec.on_error_proc)
        halt(error.message)
      else
        raise error
      end
    end

    def run_on_transition(from, to, event, *args)
      instance_exec(from.name, to.name, event, *args, &spec.on_transition_proc) if spec.on_transition_proc
    end

    def run_after_transition(from, to, event, *args)
      instance_exec(from.name, to.name, event, *args, &spec.after_transition_proc) if
        spec.after_transition_proc
    end

    def run_action(action, *args)
      instance_exec(*args, &action) if action
    end

    def has_callback?(action)
      # 1. public callback method or
      # 2. protected method somewhere in the class hierarchy or
      # 3. private in the immediate class (parent classes ignored)
      self.respond_to?(action) or
        self.class.protected_method_defined?(action) or
        self.private_methods(false).map(&:to_sym).include?(action)
    end

    def run_action_callback(action_name, *args)
      action = action_name.to_sym
      self.send(action, *args) if has_callback?(action)
    end

    def run_on_entry(state, prior_state, triggering_event, *args)
      if state.on_entry
        instance_exec(prior_state.name, triggering_event, *args, &state.on_entry)
      else
        hook_name = "on_#{state}_entry"
        self.send hook_name, prior_state, triggering_event, *args if self.respond_to? hook_name
      end
    end

    def run_on_exit(state, new_state, triggering_event, *args)
      if state
        if state.on_exit
          instance_exec(new_state.name, triggering_event, *args, &state.on_exit)
        else
          hook_name = "on_#{state}_exit"
          self.send hook_name, new_state, triggering_event, *args if self.respond_to? hook_name
        end
      end
    end

    # load_workflow_state and persist_workflow_state
    # can be overriden to handle the persistence of the workflow state.
    #
    # Default (non ActiveRecord) implementation stores the current state
    # in a variable.
    #
    # Default ActiveRecord implementation uses a 'workflow_state' database column.
    def load_workflow_state
      @workflow_state if instance_variable_defined? :@workflow_state
    end

    def persist_workflow_state(new_value)
      @workflow_state = new_value
    end
  end

  def self.included(klass)
    klass.send :include, InstanceMethods
    klass.extend ClassMethods

    if Object.const_defined?(:ActiveRecord)
      if klass < ActiveRecord::Base
        klass.send :include, Adapter::ActiveRecord::InstanceMethods
        klass.before_validation :write_initial_state
      end
    elsif Object.const_defined?(:Remodel)
      if klass < Adapter::Remodel::Entity
        klass.send :include, Remodel::InstanceMethods
      end
    end
  end
end
