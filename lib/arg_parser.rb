class ArgParser
    ALLOWED_FLAGS = [{flag: '--update-events', param_key: :update_events}, {flag: '--verify-events', param_key: :verify_events}]
    ALLOWED_FLAGS_WITH_ARG = [{flag: '--data-path=', param_key: :data_path}]
    class << self
        def parse(args)
            parsed_params = {}
            ALLOWED_FLAGS.each do |param|
                 if args.include? param[:flag]
                    parsed_params[param[:param_key]] = true
                    args.delete(param[:flag])
                 end
            end
            ALLOWED_FLAGS_WITH_ARG.each do |param| 
                flag_with_arg = args.find{|arg| arg.start_with? "#{param[:flag]}"}
                if flag_with_arg
                    parsed_params[param[:param_key]] = extract_argument(flag_with_arg.dup, param[:flag]) 
                    args.delete(flag_with_arg)
                end
            end
           
            raise "Unknown flags: #{args.join(", ")}" unless args.empty?
            parsed_params 
        end

        def extract_argument(flag_with_arg, flag)
            flag_with_arg.slice! "--data-path="
            flag_with_arg
        end
    end
end