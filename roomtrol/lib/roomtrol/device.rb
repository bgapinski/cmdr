$eventmachine_library = :pure_ruby
require 'couchrest'
require 'mq'
require 'json'

module EventMachine
	class Connection
		def associate_callback_target(sig) #:nodoc:
		# For reasons unknown, this method was commented out
		# in recent version of EM. We need it, though, for AMQP.
		end
	end
end

module Wescontrol
	# Device provides a DSL for describing devices of all kinds. Anything that
	# can be controlled by a computer—whether by IR, serial, ethernet, or laser
	# pulse—can be described by this DSL. Furthermore, in order to be part of
	# the Roomtrol system, a device _must_ be implemented as a Device. New devices
	# are created by either subclassing Device directly or by subclassing one of
	# its child classes, like RS232Device, Projector, or VideoSwitcher. If there
	# exists a class like Projector which describes the category of devices
	# that your device is pat of you should subclass it instead of Device directly.
	# Doing so will give your projector the same basic interface as every other,
	# making it easy to exchange for another. With Device, all of the details
	# of communicating with the outside world and updating the database are taken
	# care of for you, letting you focus on just implementing the device's features.
	# 
	# #Device Variables
	# The basis for this
	# DSL is the concept of state variables, defined by the state_var method.
	# State vars are—as their name suggests—variables that track the state
	# of something about the device. For example, a projector device might
	# have have a state var "power," which is true if the projector is on
	# and false if the projector is off. There are two kinds of state vars:
	# those that are immutable (e.g., the model number of the projector) and
	# those that are mutable (e.g., the aforementioned power state var).
	# Mutability is specified when the state var is created by the :editable
	# parameter, which defaults to true. Note that even an immutable state var
	# can be changed programatically by calling its device.state_var= method,
	# but controls for it will not be created in the web interface. State vars
	# can be created by placing a line like this in your class body:
	# 
	# 	state_var power, :type => :boolean
	# 
	# The type field is mandatory, but there are various other optional parameters
	# which are described in the {Device::state_var} method definition.
	# 
	# However, not every action on a device fits into the state var paradigm,
	# though you should try to use it if possible. For example, a camera may
	# have a "zoom in" and "zoom out" feature, but no way to set the zoom level
	# directly. In these cases, a command can be used instead. Calling a command
	# sends a message to the device class but does not include any state
	# information. To declare a command, the syntax below should be used:
	# 
	# 	command zoom_in
	# 
	# Command also has many options, which can be found in the {Device::command}
	# method definition.
	# 
	# Rounding out the trio of variable types, we have virtual_var. Virtual var is
	# in some ways the opposite of command: instead of providing only control, it
	# provides only information. More importantly, it is not set directly, but is
	# computed from one or more other variables. The purpose of this is primarily
	# to provide useful information for the web interface to display. For example,
	# a projector may report the number of hours a lamp has been in use as well as
	# the percentage of the lamp's life that is gone. However, the more useful metric
	# for somebody evaluating when the lamp needs to be replaced is the number of
	# hours that are left before the lamp dies. We can use simple algebra and a virtual
	# var to compute this information:
	# 
	# 	virtual_var :lamp_remaining, :type => :string, :depends_on => [:lamp_hours, :percent_lamp_used], :transformation => proc {
	# 		"#{((lamp_hours/percent_lamp_used - lamp_hours)/(60*60.0)).round(1)} hours"
	# 	}
	# 
	# Virtual vars are updated whenever the variables they depend on (which can be
	# either state vars or other virtual vars) are updated.
	# 
	# #Configuration
	# Configuration is defined by a configure block, like this, from RS232Device:
	# 
	# 	configure do
	# 		port :type => :port
	# 		baud :type => :integer, :default => 9600
	# 		data_bits 8
	# 		stop_bits 1
	# 		parity 0
	# 		message_end "\r\n"
	# 	end
	# 
	# Here we can see two kind of configuration statements: system defined and user defined.
	# The first two, port and baud, are user defined, while the rest are system defined. User
	# defined config vars are intended to be set by the user in the web interface. The type
	# parameter is a hint to the web interface about what kind of control to show and what
	# kind of validation to do on the input. For example, setting a type of :port will display
	# a drop-down of the serial ports defined for the system. A type of :integer will display
	# a text box whose input is restricted to numbers. Other possibilities are :password,
	# :string, :decimal, :boolean and :percentage. If you supply a type that is not defined
	# in the system, a simple text box will be used. An optional :default parameter can be
	# used to set the initial value.
	# 
	# System defined config vars, on the other hand, are not modifiable by the user. They are
	# specified in the device definition (as can be seen here) and cannot change. You can add
	# whatever configuration variables you need, though they should be named using lowercase
	# letters connected by underscores. Configuration information is accessible through the
	# {Device#configuration} method, which returns a hash mapping between a symbol of the name
	# to the value. More information in the {Device::configure} method definition.
	# 
	# #Controlling Devices
	# Devices are controlled externally through the use of a message queue which speaks
	# the [AMQP](http://www.amqp.org/) protocol. At the moment we use
	# [RabbitMQ](http://www.rabbitmq.com/) as the message broker, but technically everything
	# should work with another broker and RabbitMQ should not be assumed. AMQP is a very
	# complicated protocol which can support several different messaging strategies. The only
	# one used here is the simplest: direct messaging, wherein there is one sender and one
	# recipient. AMQP messages travel over "queues," which are named structures that carry
	# messages in one direction. Each device has a queue, named roomtrol:dqueue:{name} (replace
	# {name} with the actual name of the device), which it watches for messages. Messages are
	# JSON documents with at least three pieces of information: a unique ID (GUIDs are recommended
	# to ensure uniqueness), a response queue which the sender is watching, and a type. The device
	# will carry out the instructions in the message and send the response as a json message to the
	# queue specified.
	# 
	# ##Messages
	# There are three kinds of messages one can send to a device:
	# 
	# ###state_get
	# To get information about the current state of a variable, send a state_get message, which looks 
	# like the following:
	# 
	# 	!!!json
	# 	{
	# 		id: "DD2297B4-6982-4804-976A-AEA868564DF3",
	# 		queue: "roomtrol:http"
	# 		type: "state_get",
	# 		var: "input"
	# 	}
	# 
	# A state_get message returns a response like the following:
	# 
	# 	!!!json
	# 	{
	# 		id: "DD2297B4-6982-4804-976A-AEA868564DF3",
	# 		result: 5 
	# 	}
	# 
	# ###state_set
	# To set a state_var, send a state_set message
	# 
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		queue: "roomtrol:websocket"
	# 		type: "state_set",
	# 		var: "input",
	# 		value: 4
	# 	}
	# 
	# The response will look like this:
	# 
	# 	!!!json
	# 	{
	# 		"id": "FF00F317-108C-41BD-90CB-388F4419B9A1",
	# 		"result": true
	# 	}
	# 
	# ###command
	# To send a command to a device, use this:
	# 
	# 	!!!json
	# 	{
	# 		id: "FF00F317-108C-41BD-90CB-388F4419B9A1",
	# 		queue: "roomtrol:http"
	# 		type: "command",
	# 		method: "power",
	# 		args: [true]
	# 	}
	# 
	# Which will produce a response like:
	# 
	# 	!!!json
	# 	{
	# 		"id": "FF00F317-108C-41BD-90CB-388F4419B9A1",
	# 		"result": "power=true"
	# 	}
	# 
	# Any of these calls can also produce an error. Error responses look like this:
	# 
	# 	!!!json
	# 	{
	# 		"id": "FF00F317-108C-41BD-90CB-388F4419B9A1",
	# 		"error": "Failed to turn projector on"
	# 	}
	# 
	# This and the rest of the documentation here should cover everything you need to know
	# to write Device subclasses. More information can also be found in the tests, which
	# define exactly what the device class must do and not do.
	class Device
		EVENT_QUEUE = "roomtrol:events"
		attr_accessor :_id, :_rev, :belongs_to, :controller
		attr_reader :name
				
		def initialize(name, hash = {})
			hash_s = hash.symbolize_keys
			@name = name
			hash.each{|var, value|
				configuration[var.to_sym] = value
			} if configuration
			#TODO: The database uri should not be hard-coded
			@db = CouchRest.database("http://localhost:5984/rooms")
		end
		
		def run
			AMQP.start(:host => '127.0.0.1'){
				@amq_responder = MQ.new
				handle_feedback = proc {|feedback, req, resp, job|
					if feedback.is_a? EM::Deferrable
						feedback.callback do |fb|
							resp["result"] = fb
							@amq_responder.queue(req["queue"]).publish(resp.to_json)
						end
						feedback.errback do |error|
							resp["error"] = error
							@amq_responder.queue(req["queue"]).publish(resp.to_json)
						end
					else
						resp["result"] = feedback
						@amq_responder.queue(req["queue"]).publish(resp.to_json)
					end
				}
				
				amq = MQ.new
				DaemonKit.logger.info("Waiting for messages on roomtrol:dqueue:#{@name}")
				amq.queue("roomtrol:dqueue:#{@name}").subscribe{ |msg|
					DaemonKit.logger.debug("Received message: #{msg}")
					req = JSON.parse(msg)
					resp = {:id => req["id"]}
					case req["type"]
					when "command" then handle_feedback.call(self.send(req["method"], *req["args"]), req, resp)
					when "state_set" then handle_feedback.call(self.send("set_#{req["var"]}", req["value"]), req, resp)
					when "state_get" then handle_feedback.call(self.send(req["var"]), req, resp)
					else DaemonKit.logger.error "Didn't match: #{req["type"]}" 
					end
				}
			}
		end

		#this is a hook that gets called when the class is subclassed.
		#we need to do this because otherwise subclasses don't get a parent
		#class's state_vars
		def self.inherited(subclass)
			subclass.instance_variable_set(:@state_vars, {})
			self.instance_variable_get(:@state_vars).each{|name, options|
				subclass.class_eval do
					state_var(name, options.deep_dup)
				end
			} if self.instance_variable_get(:@state_vars)
			
			subclass.instance_variable_set(:@configuration, @configuration)
						
			self.instance_variable_get(:@command_vars).each{|name, options|
				subclass.class_eval do
					command(name, options.deep_dup)
				end
			} if self.instance_variable_get(:@command_vars)
		end
		
		def self.configuration
			@configuration
		end
		
		def configuration
			self.class.instance_variable_get(:@configuration)
		end
		def config_vars
			self.class.instance_variable_get(:@config_vars)
		end
		
		class ConfigurationHandler
			attr_reader :configuration
			attr_reader :config_vars
			def initialize
				@configuration = {}
				@config_vars = {}
			end
			def method_missing name, args = nil
				if args.is_a? Hash
					@configuration[name] = args[:default]
					@config_vars[name] = args
				else
					@configuration[name] = args
					@config_vars[name] = {:value => args}
				end
			end
		end
		
		def self.configure &block
			ch = ConfigurationHandler.new
			ch.instance_eval(&block)
			@configuration ||= {}
			@config_vars ||= {}
			@configuration = @configuration.merge ch.configuration
			@config_vars = @config_vars.merge ch.config_vars
		end
		
		def self.state_vars; @state_vars; end
		
		def self.state_var name, options
			sym = name.to_sym
			self.class_eval do
				raise "Must have type field" unless options[:type]
				@state_vars ||= {}
				@state_vars[sym] = options
			end
			
			self.instance_eval do
				all_state_vars = @state_vars
				define_method("state_vars") do
					all_state_vars
				end
			end
			
			self.class_eval %{
				def #{sym}= val
					if @#{sym} != val
						old_val = @#{sym}
						@#{sym} = val
						DaemonKit.logger.debug sprintf("%-10s = %s\n", "#{sym}", val.to_s)
						if virtuals = self.state_vars[:#{sym}][:affects]
							virtuals.each{|var|
								begin
									transformation = self.instance_eval &state_vars[var][:transformation]
									self.send("\#{var}=", transformation)
								rescue
									DaemonKit.logger.error "Transformation on \#{var} failed: \#{$!}"
								end
							}
						end
						if @change_deferrable
							@change_deferrable.set_deferred_status :succeeded, "#{sym}", val
							@change_deferrable = nil
							
							if @auto_register
								@auto_register.each{|block|
									register_for_changes.callback(&block)
								}
							end
						end
						self.save("#{sym}", old_val)
					end
					val
				end
				def #{sym}
					@#{sym}
				end
			}
			
			if options[:action].class == Proc
				define_method "set_#{name}".to_sym, &options[:action]
			end
		end
		
		def self.virtual_var name, options
			raise "must have :depends_on field" unless options[:depends_on]
			raise "must have :transformation field" unless options[:transformation].class == Proc
			options[:editable] = false
			self.state_var(name, options)
			options[:depends_on].each{|var|
				if @state_vars[var]
					@state_vars[var][:affects] ||= []
					@state_vars[var][:affects] << name
				end
			}
		end
		
		def self.commands; @command_vars; end
		def commands; self.class.commands; end
		
		def self.command name, options = {}
			if options[:action].class == Proc
				define_method name, &options[:action]
			end
			@command_vars ||= {}
			@command_vars[name] = options
		end
		
		def inspect
			"<#{self.class.to_s}:0x#{object_id.to_s(16)}>"
		end
		
		def to_couch
			hash = {:state_vars => {}, :config => {}, :commands => {}}
			
			if config_vars
				config_vars.each{|var, options|
					hash[:config][var] = configuration[var]
				}
			end
			
			self.class.state_vars.each{|var, options|
				if options[:type] == :time
					options[:state] = eval("@#{var}.to_i")
				else
					options[:state] = eval("@#{var}")
				end
				hash[:state_vars][var] = options
			}
			if commands
				commands.each{|var, options| hash[:commands][var] = options}
			end

			return hash
		end
		def self.from_couch(hash)
			config = {}
			hash['attributes']['config'].each{|var, value|
				config[var] = value
			}
			device = self.new(hash['attributes']['name'], config)
			device._id = hash['_id']
			device._rev = hash['_rev']
			device.belongs_to = hash['belongs_to']
			device.controller = hash['controller']
			state_vars = hash['attributes']['state_vars']
			state_vars ||= {}
			hash['attributes']['state_vars'] = nil
			hash['attributes']['command_vars'] = nil

			#merge the contents of the state_vars hash into attributes
			(hash['attributes'].merge(state_vars.each_key{|name|
				if state_vars[name]['kind'] == "time"
					begin
						state_vars[name] = Time.at(state_vars[name]['state'])
					rescue
					end
				else
					state_vars[name] = state_vars[name]['state']
				end
			})).each{|name, value|
				device.instance_variable_set("@#{name}", value)
			}
			return device
		end
		
		# Registers an error, which involves sending it as an event
		# @param [Symbol] name A symbol which uniquely identifies this error. Should
		# 	be underscore-separated and should make sense in the context of an activity feed:
		# 	for example, :projector_failed_to_turn_on, :printer_out_of_ink, :computer_unreachable
		# @param [String] description A longer description of the error, for example "Printer
		# 	PACLab_4200 has only 3% of its black ink remaining."
		# @param [Float] severity A float between 0 and 1 which indicates the severity of the 
		# 	error. Normal events are given a severity of 0.1, so should probably be in excess
		# 	of that if not completely routine.
		def register_error name, description, severity = 0.3
			message = {
				:error => true,
				:name => name,
				:description => description,
				:severity => severity
			}
			register_event message
		end
		
		# Sends an event to the event message queue
		# @param [Hash{Symbol, String => #to_json}] message The message to push onto 
		# 	the event queue; can include a :severity key, which prioritizes the message
		# 	in the web interface.
		def register_event message
			message[:device] = @_id
			message[:room] = @belongs_to
			message[:update] = true
			message[:severity] ||= 0.1
			
			@amq_responder.queue(EVENT_QUEUE, :durable => true).publish(update.to_json, :persistent => true)
		end
		
		def self.from_doc(id)
			from_couch(CouchRest.database(@database).get(id))
		end
		
		def save changed = nil, old_val = nil
			retried = false
			begin
				hash = self.to_couch
				doc = {'attributes' => hash, 'class' => self.class, 'belongs_to' => @belongs_to, 'controller' => @controller, 'device' => true}
				if @_id && @_rev
					doc["_id"] = @_id
					doc["_rev"] = @_rev
				end
				@_rev = @db.save_doc(doc)['rev']
			rescue => e
				if !retried
					retried = true
					retry
				else
					DaemonKit.logger.exception e
				end
			end
			if changed
				update = {
					'var' => changed,
					'now' => self.instance_variable_get(changed),
					'importance' => self.state_vars
				}
				update['was'] = old_val if old_val
				register_event update
			end
		end
		
		def register_for_changes
			@change_deferrable ||= EM::DefaultDeferrable.new
			@change_deferrable
		end
		
		def auto_register_for_changes(&block)
			@auto_register ||= []
			@auto_register << block
			register_for_changes.callback(&block)
		end
	end
end

#Thes methods dup all objects inside the hash/array as well as the data structure itself
#However, because we don't check for cycles, they will cause an infinite loop if present
class Object
	def deep_dup
		begin
			self.dup
		rescue
			self
		end
	end
end

class Hash
	def symbolize_keys!
		t = self.dup
		self.clear
		t.each_pair{|k, v| self[k.to_sym] = v}
		self
	end
	def symbolize_keys
		t = {}
		self.each_pair{|k, v| t[k.to_sym] = v}
		t
	end
	def deep_dup
		new_hash = {}
		self.each{|k, v| new_hash[k] = v.deep_dup}
		new_hash
	end
end

class Array
	def deep_dup
		self.collect{|x| x.deep_dup}
	end
end