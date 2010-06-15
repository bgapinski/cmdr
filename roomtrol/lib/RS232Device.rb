require 'rubygems'
require 'em-serialport'
require 'bit-struct'

module Wescontrol
	class RS232Device < Device
		attr_accessor :serialport
		
		configure do
			port :expects => :port
			baud 9600
			data_bits 8
			stop_bits 1
			parity 0
		end
				
		def send_string(string)
			@serialport.send_data(string) if @serialport
		end
		
		def read data
		end
	
		protected
		def initialize(options)
			puts "Initialized"
			options = options.symbolize_keys
			@port = options[:port]
			throw "Must supply serial port parameter" unless @port
			@baud = options[:baud] ? options[:baud] : 9600
			@data_bits = options[:data_bits] ? options[:data_bits] : 8
			@stop_bits = options[:stop_bits] ? options[:stop_bits] : 1
			@parity = options[:parity] ? options[:parity] : 0
			my_connection = RS232Connection.dup
			my_connection.instance_variable_set(:@receiver, self)
			#Thread.new {
				EM::run { EM::open_serial @port, @baud, @data_bits, @stop_bits, @parity, my_connection}
			#}
			super(options)
		end
	end
end

class RS232Connection < EM::Connection
	def initialize
		@receiver ||= self.class.instance_variable_get(:@receiver)
		@receiver.serialport = self
	end
	def receive_data data
		@receiver.read data if @receiver
	end	
end
