#!/usr/bin/env ruby
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))
  HELP = <<-EOH
  Unfortunately, the agent script has some difficult requirements right now.
  Please see https://github.com/lusis/Noah/Watcher-Agent for details.
  EOH
begin
  require 'rubygems'
  require 'logger'
  require 'optparse'
  require 'em-hiredis'
  require 'eventmachine'
  require 'em-http-request'
  require 'noah'
  require 'noah/agent'
  require 'json'
rescue LoadError => e
  puts e.message
  puts HELP
  exit
end

Noah::Log.logger = Logger.new(STDOUT)
LOGGER = Noah::Log.logger
LOGGER.progname = __FILE__

EventMachine.run do
  EM.error_handler do |e|
    LOGGER.warn(e)
  end
  trap("INT") { LOGGER.debug("Shutting down. Watches will not be fired");EM.stop }
  noah = Noah::Agent.new
  noah.errback{|x| LOGGER.error("Errback: #{x}")}
  noah.callback{|y| LOGGER.info("Callback: #{y}")}
  # Passing messages...like a boss
  #master_channel = EventMachine::Channel.new

  r = EventMachine::Hiredis::Client.connect
  r.errback{|x| LOGGER.error("Unable to connect to redis: #{x}")}
  LOGGER.info("Attaching to Redis Pubsub")
  r.psubscribe("*")
  r.on(:pmessage) do |pattern, event, message|
    noah.reread_watchers if event =~ /^\/\/noah\/watchers\/.*/
    noah.broker("#{event}|#{message}") unless noah.watchers == 0
    #master_channel.push "#{event}|#{message}"
  end

  #sub = master_channel.subscribe {|msg|
    # We short circuit if we have no watchers
  #  noah.broker(msg) unless noah.watchers == 0
  #}
end