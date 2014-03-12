require 'ftw/agent'
require 'ftw/socket_connection'
class FTW::SocketAgent < FTW::Agent

  def initialize( socket )
    @socket = socket
    super()
  end

  def connect(_, _, secure=false)
    error = nil
    connection = @pool.fetch(@socket) do
      connection = FTW::SocketConnection.new(@socket)
      error = connection.connect
      if !error.nil?
        nil
      else
        connection
      end
    end

    if !error.nil?
      @logger.error("Connection failed", :error => error)
      return nil, error
    end

    @logger.debug("Pool fetched a connection", :connection => connection)
    connection.mark

    if secure
      # Curry a certificate_verify callback for this connection.
      verify_callback = proc do |verified, context|
        begin
          certificate_verify(host, port, verified, context)
        rescue => e
          @logger.error("Error in certificate_verify call", :exception => e)
        end
      end
      connection.secure(:certificate_store => @certificate_store,
                        :verify_callback => verify_callback)
    end # if secure

    return connection, nil
  end

end
