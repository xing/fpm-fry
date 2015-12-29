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

  end
end ; end
