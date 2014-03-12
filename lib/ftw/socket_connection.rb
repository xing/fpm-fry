require 'ftw/connection'
class FTW::SocketConnection < FTW::Connection

  def connect(timeout=nil)
    disconnect("reconnecting") if connected?
    current = @destinations.first
    @destinations = @destinations.rotate # round-robin
    @logger.debug("Connecting", :socket => current)
    begin
      @socket = UNIXSocket.new(current)
      @remote_address = current
      @connected = true
    rescue => e
      @remote_address = nil
      @connected = false
      return e
    end
    return nil
  end

end
