require 'sinatra/base'
require 'set'
require 'digest/sha1'
require 'yaml'

DEVELOPMENT = ENV['DEVELOPMENT']

class Main < Sinatra::Base
    configure do
        set :show_exceptions, false
    end

    def assert(condition, message = 'assertion failed')
        raise message unless condition
    end

    def test_request_parameter(data, key, options)
        type = ((options[:types] || {})[key]) || String
        assert(data[key.to_s].is_a?(type), "#{key.to_s} is a #{type}")
        if type == String
            assert(data[key.to_s].size <= (options[:max_value_lengths][key] || options[:max_string_length]), 'too_much_data')
        end
    end

    def parse_request_data(options = {})
        options[:max_body_length] ||= 512
        options[:max_string_length] ||= 512
        options[:required_keys] ||= []
        options[:optional_keys] ||= []
        options[:max_value_lengths] ||= {}
        data_str = request.body.read(options[:max_body_length]).to_s
        @latest_request_body = data_str.dup
        begin
            assert(data_str.is_a? String)
            assert(data_str.size < options[:max_body_length], 'too_much_data')
            data = JSON::parse(data_str)
            @latest_request_body_parsed = data.dup
            result = {}
            options[:required_keys].each do |key|
                assert(data.include?(key.to_s))
                test_request_parameter(data, key, options)
                result[key.to_sym] = data[key.to_s]
            end
            options[:optional_keys].each do |key|
                if data.include?(key.to_s)
                    test_request_parameter(data, key, options)
                    result[key.to_sym] = data[key.to_s]
                end
            end
            result
        rescue
            STDERR.puts "Request was:"
            STDERR.puts data_str
            raise
        end
    end


    post '/' do
        form = request.body.read
        decoded_form = URI.decode_www_form(form)
        data = Hash[decoded_form]
        STDERR.puts data.to_yaml
        if data['event'] == 'newCall'
            STDERR.puts "NEW CALL!"
            xml = StringIO.open do |io|
                io.puts "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
                io.puts "<Response>"
                io.puts "<Gather maxDigitis=\"1\" timeout=\"5000\" onData=\"https://ivr.hackschule.de\">"
                io.puts "<Play>"
                io.puts "<Url>https://ivr-assets.nhcham.org/1667403886950.wav</Url>"
                io.puts "</Play>"
                io.puts "</Gather>"
                io.puts "</Response>"
                io.string
            end
            response.headers['Content-Type'] = 'application/xml'
            response.headers['Content-Length'] = xml.size
            response.body = xml
        end
        return
    end

    run! if app_file == $0
end
