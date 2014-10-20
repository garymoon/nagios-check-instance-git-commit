#!/usr/bin/env ruby
require 'rubygems'
require 'aws-sdk'
require 'optparse'
require 'net/http'

EXIT_CODES = {
  :unknown => 3,
  :critical => 2,
  :warning => 1,
  :ok => 0
}

options =
{
  :debug => false,
  :groups => [],
  :stack => '',
  :string => '',
  :user => '',
  :pass => '',
  :host => '',
  :port => '80',
  :ssl => false,
  :spoof_https => false,
  :verify_mode => OpenSSL::SSL::VERIFY_PEER,
  :tags => []
}

config = { :region => 'us-west-2' }

opt_parser = OptionParser.new do |opt|

  opt.on("--groups group[,group]","which specific ASG do you wish to report on?") do |groups|
    options[:groups] = groups.split(',')
  end

  opt.on("--stack stack","which specific stack do you wish to report on?") do |stack|
    options[:stack] = stack
  end

  opt.on("--port port","specify the port the instance is listening on") do |port|
    options[:port] = port
  end

  opt.on("--host host","specify the host header to use") do |host|
    options[:host] = host
  end

  opt.on("--tags tag,[tag]","which specific tag(s) do you wish to report on?") do |tags|
    options[:tags] = tags.split(',')
  end

  opt.on("-k","--key key","specify your AWS key ID") do |key|
    (config[:access_key_id] = key) unless key.empty?
  end

  opt.on("-s","--secret secret","specify your AWS secret") do |secret|
    (config[:secret_access_key] = secret) unless secret.empty?
  end

  opt.on("--debug","enable debug mode") do
    options[:debug] = true
  end

  opt.on("--ssl","enable SSL") do
    options[:ssl] = true
  end

  opt.on("--user username","username") do |user|
    options[:user] = user unless user.empty?
  end

  opt.on("--pass password","password") do |pass|
    options[:pass] = pass unless pass.empty?
  end

  opt.on("--insecure","Disable SSL peer verification") do
    options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
  end

  opt.on("--spoof-https","Spoof HTTPS from a proxy with X-Forwarded-Proto") do
    options[:spoof_https] = true
  end

  opt.on("--region region","which region do you wish to report on?") do |region|
    config[:region] = region
  end

  opt.on("-h","--help","help") do
    puts opt_parser
    exit
  end
end

opt_parser.parse!

raise OptionParser::MissingArgument, 'Missing "--user" or "--pass"' if (options[:user].empty? ^ options[:pass].empty?)
raise OptionParser::MissingArgument, 'Missing "--stack" or "--tags"' if (options[:stack].empty? ^ !options[:tags].empty?)
raise OptionParser::MissingArgument, 'Missing "--stack" & "--tags", or "--groups"' if ((options[:stack].empty?) and (options[:groups].empty?))
raise OptionParser::MissingArgument, 'Missing "--secret" or "--key"' if (options[:key] ^ !options[:secret])

if (options[:debug])
  puts 'Options: '+options.inspect
  puts 'Config: '+config.inspect
end

AWS.config(config)
instances = []

begin
  as = AWS::AutoScaling.new
  stacks = AWS::CloudFormation.new.stacks
  AWS.memoize do
    options[:tags].each do |tag_name|
      as.groups[stacks[options[:stack]].resources[tag_name].physical_resource_id].ec2_instances.each do |instance|
        if (instance.status == :running)
          instances << instance
        end
      end
    end
    puts "#{instances.length} instances" if options[:debug]
    if (instances.empty?)
      puts 'CRIT: No instances to check!'
      exit EXIT_CODES[:critical]
    end
    commits = {}
    instances.each do |instance|
      print "#{instance.private_ip_address}: " if options[:debug]
      Net::HTTP.start(instance.private_ip_address, options[:port], :use_ssl => options[:ssl], :verify_mode => options[:verify_mode]) do |http|
        request = Net::HTTP::Get.new '/version.cfm'

        if (options[:user]) then
          request.basic_auth options[:user], options[:pass]
        end

        if (options[:host])
          request.add_field("Host", options[:host])
        end

        if (options[:spoof_https])
          request.add_field("X-Forwarded-Proto", "https")
        end

        response = http.request request

        commit_id = response.body.strip
        puts commit_id if options[:debug]
        if (commit_id.length != 40)
          puts "CRIT: #{instance.id} is not reporting a valid commit ID."
          exit EXIT_CODES[:critical]
        end
        if (commits[commit_id])
          commits[commit_id] << instance.id
        else
          commits[commit_id] = [instance.id]
        end
      end
    end
    if (commits.length > 1)
      puts 'CRIT: There is some disparity among the servers:'
      commits.each do |commit, instances|
        puts commit + ': ' + ','.join(instances)
      end
      exit EXIT_CODES[:critical]
    end
  end
rescue SystemExit
  raise
rescue Exception => e
  puts 'CRIT: Unexpected error: ' + e.message + ' <' + e.backtrace[0] + '>'
  exit EXIT_CODES[:critical]
end


puts 'OK: All instances are running the same code.'
exit EXIT_CODES[:ok]
