nagios-check-instance-git-commit
================================

A Nagios check for monitoring the git commit an AutoScaling group is running on.

This check is pretty purpose-built, but maybe it will be useful to someone with a similar purpose. It connects to a URI on each instance in an AutoScaling group that returns the commit ID of the code it's running on. If there's any disparity, the check fails.

    Usage: check_instance_git_commit [options]
            --groups group[,group]       which specific ASG do you wish to report on?
            --stack stack                which specific stack do you wish to report on?
            --port port                  specify the port the instance is listening on
            --host host                  specify the host header to use
            --tags tag,[tag]             which specific tag(s) do you wish to report on?
        -k, --key key                    specify your AWS key ID
        -s, --secret secret              specify your AWS secret
            --debug                      enable debug mode
            --ssl                        enable SSL
            --user username              username
            --pass password              password
            --insecure                   Disable SSL peer verification
            --spoof-https                Spoof HTTPS from a proxy with X-Forwarded-Proto
            --region region              which region do you wish to report on?
        -h, --help                       help

Configuration
-------------

    define command{
      command_name  check_instance_git_commit
      command_line  $USER1$/check_instance_git_commit.rb --stack '$ARG1$' --tags '$ARG2$' --key '$ARG3$' --secret '$ARG4$' --region '$ARG5$' --host '$ARG6$' --user '$ARG7$' --pass '$ARG8$' --spoof-https
      }

    define service{
      use                             generic-service 
      host_name                       aws
      service_description             Instance Git Commit
      check_command                   check_instance_git_commit!<%= @aws_cfn_stack %>!WWWFleet!<%= @aws_nagios_key %>!<%= @aws_nagios_secret %>!<%= @aws_region_code %>!<%= @primary_domain %>!user!pass!
      check_interval                  5
      notification_period             workhours
      first_notification_delay        30
    }


Notes:
* It only works on a tagged cfn stack. Could be made to accept autoscaling group names if there's interest.
* The default region is us-west-2 (Oregon).