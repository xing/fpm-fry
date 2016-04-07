require 'cabin/channel'
module FPM; module Fry
  class Channel < Cabin::Channel

    module Hint
      def hint( message, data = {} )
        return unless hint?
        log(message, data.merge(level: :hint))
      end

      def hint?
        !defined?(@hint) || @hint
      end

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
