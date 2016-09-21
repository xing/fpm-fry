require 'fpm/fry/with_data'
require 'open3'
module FPM
  module Fry

    module Exec

      # Raised when running a command failed.
      class Failed < StandardError
        include WithData

        # @return [String] contents of stderr
        def stderr
          data[:stderr]
        end

      end

      class << self

        # @!method [](*cmd, options = {})
        #   Runs a command and returns its stdout as string. This method is preferred if the expected output is short.
        #  
        #   @param [Array<String>] cmd command to run
        #   @param [Hash] options
        #   @option options [Cabin::Channel] :logger
        #   @option options [String] :description human readable string to describe what the command is doing
        #   @option options [String] :stdin_data data to write to stding
        #   @option options [String] :chdir directory to change to
        #   @return [String] stdout
        #   @raise [FPM::Fry::Exec::Failed] when exitcode != 0
        #
        def [](*args)
          cmd, options, description = extract_options_and_log(args)
          stdout, stderr, status = Open3.capture3(*cmd, options)
          if status.exitstatus != 0
            raise Exec.const_get("ExitCode#{status.exitstatus}").new("#{description} failed", exitstatus: status.exitstatus, stderr: stderr, stdout: stdout, command: cmd)
          end
          return stdout
        end

        alias exec []

        # @!method popen(*cmd, options = {})
        #   Runs a command and returns its stdout as IO.
        #  
        #   @param [Array<String>] cmd command to run
        #   @param [Hash] options
        #   @option options [Cabin::Channel] :logger
        #   @option options [String] :description human readable string to describe what the command is doing
        #   @option options [String] :chdir directory to change to
        #   @return [IO] stdout
        #
        def popen(*args)
          cmd, options, _description = extract_options_and_log(args)
          return IO.popen(cmd, options)
        end
private
        def extract_options_and_log(args)
          options = args.last.kind_of?(Hash) ? args.pop.dup : {}
          cmd = args
          logger = options.delete(:logger)
          description = options.delete(:description) || "Running #{cmd.join(' ')}"
          if logger
            logger.debug(description, command: args)
          end
          return cmd, options, description
        end

        def const_missing(name)
          if name.to_s =~ /\AExitCode\d+\z/
            klass = Class.new(Failed)
            const_set(name, klass)
            return klass
          end
          super
        end

      end
    end
  end
end
