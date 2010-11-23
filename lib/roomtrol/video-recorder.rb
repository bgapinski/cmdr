require 'mq'
require 'fileutils'

module RoomtrolVideo
	# This class is reponsible for recording video and playing back the current state of
	# the camera. It is controlled over AMQP. There are several kinds of messages you can
	# send over the wire, all of which should be encoded via JSON. In each of these messages,
	# id is a unique id which the client can use to recognize a response (as each response
	# will also include this id) and queue is the queue to which the client wants the response
	# sent.
	# 
	# ###start_time_get
	# To get the time that recording started at, send a message like this:
	#
	# 	!!!json
	# 	{
	# 		id: "FF00F317-108C-41BD-90CB-388F4419B9A1",
	# 		queue: "roomtrol:video_recorder:35",
	# 		get: "start_time"
	# 	}
	# You will get a response like this:
	# 	!!!json
	# 	{
	# 		id: "FF00F317-108C-41BD-90CB-388F4419B9A1",
	# 		result: "2010-10-19 17:45:29 -0400"
	# 	}
	#
	# ###current_state_get
	# To get the current state (one of RemoteRecorder::PlayingState, 
	# RemoteRecorder::RECORDING_STATE or RemoteRecorder::STOPPED_STATE):
	# 
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		queue: "roomtrol:video_recorder:35",
	# 		get: "current_state"
	# 	}
	# You will get a response like this:
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		result: "playing"
	# 	}
	# ###start_recording
	#
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		queue: "roomtrol:video_recorder:35",
	# 		command: "start_recording"
	# 	}
	# You will get a response like this:
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		result: true #on success, false on failure
	# 		start_time: "2010-10-19 17:45:29 -0400"
	# 	}
	#
	# ###start_playing
	#
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		queue: "roomtrol:video_recorder:35",
	# 		command: "start_playing"
	# 	}
	# You will get a response like this:
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		result: true #on success, false on failure
	# 	}
	# ###stop
	#
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		queue: "roomtrol:video_recorder:35",
	# 		command: "stop" #stops current command
	# 	}
	# You will get a response like this:
	# 	!!!json
	# 	{
	# 		id: "D62F993B-E036-417C-948B-FEA389480984",
	# 		result: true, #on success, false on failure
	# 		stop_time: "20-10-19 17:50:29 -0400"
	# 	}
	#
	#
	# If you register yourself on the message fanout exchange (at 
	# RemoteRecorder::FANOUT_EXCHANGE), you will receive messages when interesting
	# things happen. Below are the messages you might receive:
	#
	# 	!!!json
	# 	{
	# 		message: "state_changed",
	# 		from: "playing",
	# 		to: "stopped"
	# 	}
	#
	# 	{
	#		message: "playback_died",
	# 		restarts_left: 4
	# 	}
	#
	# 	{
	# 		message: "recording_died",
	# 		restarts_left: 3
	# 		new_file: "/var/video/2010/10/20/04.10.50.avi.7"
	# 	}
	class RemoteRecorder
		# The command to start recording video
		RECORD_CMD = %q?
		gst-launch v4l2src ! 'video/x-raw-yuv,width=720,height=480,framerate=30000/1001' ! \
		    tee name=t_vid ! queue ! \
		    xvimagesink sync=false t_vid. ! queue ! \
		    videorate ! 'video/x-raw-yuv,framerate=30000/1001' ! deinterlace ! queue ! mux. \
		    audiotestsrc ! audio/x-raw-int,rate=48000,channels=2,depth=16 ! queue ! \
		    audioconvert ! queue ! mux. avimux name=mux ! \
		    filesink location=OUTPUT_FILE?

		# The command to start video playback, but not record
		PLAY_CMD =  %q?
		gst-launch v4l2src ! 'video/x-raw-yuv,width=720,height=480,framerate=30000/1001' ! \
		    queue ! \
		    xvimagesink sync=false . ?
		
		# Currently playing video back
		PLAYING_STATE = :playing
		# Currently recording video
		RECORDING_STATE = :recording
		# Currently stopped
		STOPPED_STATE = :stopped
		# The queue on which the recorder sends fanout messages to interested parties
		FANOUT_EXCHANGE = "roomtrol:video:messages"
		# The number of times to try restarting a recording that has stopped
		RESTART_LIMIT = 10
		# The number of times per second to checkup on processess
		WATCH_FREQUENCY = 4	
	
		attr_accessor :recording_start_time, :state
	
		# Creates a new RemoteRecorder instance
		# @param [String] response_queue The name of the queue over which messages should
		# 	be sent from the recorder to the client. The client should watch this queue.
		# @param [String] send_queue The name of the queue over which the client would like
		# 	to send messages to the recorder. It will watch this queue.
		def initialize send_queue
			@state = STOPPED_STATE
			@send_queue = send_queue
		end
		
		# Starts the recording server. Until this is called, the recorder will not respond
		# to messages.
		def run
			AMQP.start(:host => '127.0.0.1') do
				mq = MQ.new
				@fanout = MQ.new.fanout(FANOUT_EXCHANGE)
				mq.queue(@send_queue).subscribe do |msg|
					DaemonKit.logger.debug("Received: #{msg}")
					req = JSON.parse(msg)
					resp = {:id => req["id"]}
					if req['get']
						case req['get']
						when "start_time"
							resp[:result] = @recording_start_time
						when "current_state"
							resp[:result] = @state
						else
							resp[:error] = "Invalid request"
						end
					elsif req['command']
						case req['command']
						when "start_playing"
							resp[:result] = !!start_playback
						when "start_recording"
							resp[:result] = !!start_recording
							resp[:start_time] = @recording_start_time
						when "stop"
							resp[:result] == !!stop
						else
							resp[:error] = "Invalid command"
						end
					else
						resp[:error] = "Invalid message"
					end
					mq.queue(req["queue"]).publish(resp.to_json)
				end
				EM.add_periodic_timer(1.0/WATCH_FREQUENCY) do
					watch
				end
			end
		end
	
		def start_playback
			if @current_pid
				kill_command @current_pid
			end
			self.state = PLAYING_STATE
			@restart_count = RESTART_LIMIT
			@current_pid = start_command PLAY_CMD
		end
	
		def start_recording
			if @current_pid
				kill_command @current_pid
			end
			@recording_start_time = Time.now
			@restart_count = RESTART_LIMIT
			self.state = RECORDING_STATE
			file = filename_for_time(@recording_start_time)
			FileUtils.mkdir_p file[0]
			@current_pid = start_command RECORD_CMD.gsub("OUTPUT_FILE", file.join("/"))
		end
	
		def stop
			puts "Stopping #{@current_pid}"
			if @current_pid
				self.state = STOPPED_STATE
				kill_command @current_pid
			end
		end
	
		def watch
			case @state
			when PLAYING_STATE
				if !alive?(@current_pid)
					DaemonKit.logger.debug("Playing but not alive on #{@current_pid}")
					if @restart_count <= 0
						self.state = STOPPED_STATE
					else
						@restart_count = @restart_count.to_i - 1
						@current_pid = start_command PLAY_CMD
						send_fanout({
							:message => :recording_died,
							:restart_count => @restart_count
						})
					end
				else
					@restart_count = RESTART_LIMIT
				end
			when RECORDING_STATE
				if !alive?(@current_pid)
					if @restart_count <= 0
						self.state = STOPPED_STATE
					else
						@restart_count = @restart_count.to_i - 1
						file = filename_for_time(@recording_start_time)
						FileUtils.mkdir_p file[0]
						new_filename = "#{file.join("/")}.#{RESTART_LIMIT-@restart_count}"
						@current_pid = start_command RECORD_CMD.gsub("OUTPUT_FILE", new_filename)
						send_fanout({
							:message => :recording_died,
							:restart_count => @restart_count,
							:new_file => new_filename
						})
					end
				else
					@restart_count = RESTART_LIMIT
				end
			else
				if !alive?(@current_pid)
					self.state = STOPPED_STATE
				end
			end
		end
	
		private
		def state= new_state
			if @state != new_state
				send_fanout({
					:message => :state_changed,
					:from => @state,
					:to => new_state,
					:time => new_state == RECORDING_STATE ? @recording_start_time : Time.now
				})
			end
			@state = new_state
		end
		#Thanks to God's process.rb for inspiration for the following methods
		def kill_command pid
			5.times{|time|
				begin
					Process.kill(2, pid)
				rescue Errno::ESRCH
					return
				end
				sleep 0.1
			}
		
			Process.kill('KILL', pid) rescue nil
		end
	
		def alive? pid
			#double exclamation mark returns true for a non-false values
			!!Process.kill(0, pid) rescue false
		end
	
		def start_command cmd
			r, w = IO.pipe
			begin
				outside_pid = fork do
					STDOUT.reopen(w)
					r.close
					pid = fork do
						#Process.setsid
						#Dir.chdir '/'
						$0 = cmd
						STDIN.reopen("/dev/null")
						STDOUT.reopen("/dev/null")
						STDERR.reopen(STDOUT)
						3.upto(256){|fd| IO.new(fd).close rescue nil}
						exec cmd
					end
					puts pid.to_s
				end
				Process.waitpid(outside_pid, 0)
				w.close
				pid = r.gets.chomp.to_i
				puts "Parent: #{pid}"
			ensure
				r.close rescue nil
				w.close rescue nil
			end
			puts "Starting command as #{child_pids(pid)[0]}"
			child_pids(pid)[0].to_i
		end
	
		def filename_for_time(time)
			dir = "/var/video/#{time.year}/#{time.month}/#{time.day}"
			file = "#{time.hour}.#{time.min}.#{time.sec}.avi"
			[dir, file]
		end
		def send_fanout hash
			@fanout.publish(hash.to_json)
		end
		def child_pids pid
			`ps -ef | grep #{pid}`.split("\n").collect{|line| line.split(/\s+/)}.reject{|parts| 
				parts[2] != pid.to_s || parts[-2] == "grep"
			}.collect{|parts| parts[1]}
		end
	end
end
