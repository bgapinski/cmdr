# Copyright (C) 2014 Wesleyan University
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'mq'
require 'couchrest'
require 'cmdr/authenticate'
module Cmdr
  # This class is responsible for watching the event queue, buffering the events and
  # protecting the database from too-frequent updates (which can easily happen in the
  # case of a slider control of continuous variables, like volume). Instead of dumping
  # all of those events on the database, it reports only the first and last event of
  # a stream.
  class EventMonitor
    # The number of seconds to wait before processing the next batch of events
    TIMEOUT = 5.0
    # A blocking method which starts event monitoring inside an EventMachine.
    def self.run
      buffer = {}
      AMQP.start(:host => '127.0.0.1'){
        @credentials = Authenticate.get_credentials
        db = CouchRest.database("http://#{@credentials["user"]}:#{@credentials["password"]}@localhost:5984/rooms")
        topic = MQ.new.topic(EVENT_TOPIC)
        MQ.new.queue("cmdr:event-monitor").bind(topic, :key => "*").subscribe do |json|
          begin
            msg = JSON.parse(json)
            msg[:event] = true
            # make this that the event we're looking is really a state update event
            if msg['state_update'] && msg['var'] && msg['now']
              buffer[msg['var']] ||= {:events => []}
              buffer[msg['var']][:events] << msg
              buffer[msg['var']][:time] = Time.now
            end
          rescue JSON::ParserError
            DaemonKit.logger.error("Failed to parse event: '#{json}'")
          end
        end
        EM::add_periodic_timer(TIMEOUT) do
          buffer.delete_if{|var, hash|
            #only process the events if it's been at least TIMEOUT seconds since the last event
            hash[:time] + TIMEOUT >= Time.now ? false :
              case hash[:events].size
              when 1
                db.save_doc(hash[:events][0])
              when 2
                db.save_doc(hash[:events][0])
                db.save_doc(hash[:events][1])
              else
                if hash[:events].size > 2
                  db.save_doc(hash[:events][0])
                  db.save_doc(hash[:events][-1])
                end
              end
          }
        end
      }
    end
  end
end
