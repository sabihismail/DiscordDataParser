require_relative '../utils'
require_relative '../processors/message_content_processor'
require_relative '../processors/message_by_date_processor'
class MessagesAnalyzer
    attr_reader :path, :message_by_content_processor, :message_by_date_processor

    def initialize(path, params)
        @path = path
        @message_by_content_processor = MessageByContentProcessor.new
        @message_by_date_processor = MessageByDateProcessor.new
    end

    def call
        raise "Directory doesn't exist\n" unless File.directory? path
        message_index = Utils::parse_json_from_file("#{path}/index.json")
        total_threads = Utils::get_num_of_directories(path)
        @start_time = Time.now
        puts 'Begin parsing messages...'
        message_index.each_with_index do |(thread_id, thread_name), index|
            thread_name = thread_name.nil? ? 'unknown_user': thread_name
            puts "Progress: #{index + 1}/#{total_threads} (#{thread_name})"
            parse_message_file("#{path}/#{thread_id}/messages.csv", thread_name)
        end
        @end_time = Time.now
        results(output)
    end

    def results(output)
        output_files = []
        [:by_date, :by_time_of_day, :by_day_of_week, :per_thread, :commonly_used_words].each do |type|
            Utils::write_output_csv(output, 'messages' ,type) {|output_file| output_files.push(output_file)}
        end
        {
            output_files: output_files,
            output_strings: [
               "Message Analysis #{(@end_time - @start_time).round(1)}s",
               "-----------------------------------",
               "Total Messages: #{output[:total_message_count]}",
               "Average words per sentence: #{output[:average_words_per_message]}",
               "Average messages per day: #{output[:average_messages_per_day]}",
               "Most used word: #{output[:commonly_used_words][0]}",
               "Most active thread: #{output[:per_thread][0]}\n"
            ]
        }
    end

    def output 
        [message_by_date_processor.output, message_by_content_processor.output(message_by_date_processor.output[:by_date].length)].reduce({}, :merge)
    end

    private 
    def parse_message_file(file_path, thread_name)
        csv_lines = Utils::read_csv_from_file(file_path)
        csv_lines.shift
        csv_lines = csv_lines.map do |csv_line|
            begin
                {
                    date_time: Time.parse(csv_line[1]) + Time.zone_offset(Utils::TIMEZONE),
                    message: csv_line[2],
                    attachments: csv_line[3]
                }
            rescue
                puts "Could not parse csv line"
                return {}
            end
        end
        new_data(csv_lines, thread_name)
    end

    def new_data(lines, thread_name)
        message_by_content_processor.process_messages_by_thread(lines, thread_name)
        lines.each do |line|
            message_by_content_processor.process(line)
            message_by_date_processor.process(line)
        end
    end
end