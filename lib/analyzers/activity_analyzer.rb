require_relative '../utils'
require_relative '../processors/voice_processor'
require_relative '../processors/game_processor'
require_relative '../processors/reaction_processor'
require_relative '../processors/session_processor'
require_relative '../processors/verify_events_processor'
class ActivityAnalyzer
    attr_reader :path, :session_processor, :reaction_processor, :game_processor, :voice_processor, :verify_events_processor
    attr_accessor :games
    def initialize(path, params)
        @params = params
        @path = path
        @session_processor = SessionProcessor.new
        @reaction_processor = ReactionProcessor.new
        @game_processor = GameProcessor.new
        @voice_processor = VoiceProcessor.new
        @verify_events_processor = VerifyEventsProcessor.new(@params[:verify_events], @params[:update_events])
    end

    def call
        raise "Directory doesn't exist\n" unless File.directory? path
        @start_time = Time.now
        puts 'Begin parsing activity...'
        list = Hash.new(0)
        Dir.foreach(path) do |activity_log| 
            next if activity_log == '.' or activity_log == '..'
            Utils::parse_funky_new_line_json_array("#{path}/#{activity_log}") do |parsed_activity_line|
                event_type = parsed_activity_line['event_type']
                verify_events_processor.process(event_type)
                next if verify_events?
                session_processor.process(parsed_activity_line, event_type) if ['session_end', 'session_start', 'app_opened'].include? event_type
                reaction_processor.process(parsed_activity_line, event_type) if ['add_reaction', 'remove_reaction'].include? event_type
                game_processor.process(parsed_activity_line, event_type) if ['launch_game', 'game_opened'].include? event_type
                voice_processor.process(parsed_activity_line) if ['join_voice_channel'].include? event_type
            end
        end
        @end_time = Time.now
        results(output)
    end

    def results(output)
        output_files = []
        [:games_play_count, :time_by_os, :time_by_location, :time_by_device, :reactions_by_use].each do |type|
            Utils::write_output_csv(output, 'activity' , type) {|output_file| output_files.push(output_file)}
        end
        {
            output_files: output_files,
            output_strings: [
               "Activity Analysis #{(@end_time - @start_time).round(1)}s",
               "-----------------------------------",
               "Total Sessions: #{output[:total_sessions]}",
               "Average session length: #{output[:average_session_length]} minutes" ,
               "App opened #{output[:total_app_open]} times",
               "Total Reactions Added: #{output[:total_reactions_added]}",
               "Total Reactions Removed: #{output[:total_reactions_removed]}",
               "Total Voice Channels Joined: #{output[:total_voice_channel_connections]}\n"
            ]
        }
    end

    private
    def output 
        [verify_events_processor.output] if verify_events?
        [session_processor.output, reaction_processor.output, game_processor.output, voice_processor.output, verify_events_processor.output].reduce({}, :merge)
    end
 
    def verify_events? 
        @params[:verify_events] || @params[:update_events]
    end

end

