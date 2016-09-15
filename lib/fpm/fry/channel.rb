require 'cabin/channel'
module FPM; module Fry
  # A {Cabin::Channel} with two additional features:
  #
  # - There is a new log level 'hint' which can point users to improvements.
  # - Logging an Exception that responds to #data will merge in the data from 
  #   this exception. This is used together with {FPM::Fry::WithData}
  #
  # @api internal
  class Channel < Cabin::Channel

    module Hint
      # Logs a message with level 'hint'
      #
      # @param [String] message
      # @param [Hash] data
      def hint( message, data = {} )
        return unless hint?
        log(message, data.merge(level: :hint))
      end

      # True if hints should be displayed
      def hint?
        !defined?(@hint) || @hint
      end

      # Switched hints on or off
      def hint=( bool )
        @hint = !!bool
      end
    end

    include Hint

    # @private
    def _log(message, data={})
      case message
      when Hash
        data.merge!(message)
      when Exception
        # message is an exception
        data[:message] = message.to_s
        data[:exception] = message
        data[:backtrace] = message.backtrace
        if message.respond_to? :data
          data = message.data.merge(data)
        end
      else
        data = { :message => message }.merge(data)
      end

      publish(data)
    end

  end
end ; end
