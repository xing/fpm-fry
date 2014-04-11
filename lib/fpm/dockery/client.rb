require 'ftw/request'
require 'ftw/connection'
require 'ftw/socket_connection'
require 'ftw/socket_agent'
require 'rubygems/package'
require 'json'
require 'fileutils'

module FPM; module Dockery; end ; end

class FPM::Dockery::Client

  attr :docker_url, :logger

  def initialize(options = {})
    @docker_url = options.fetch(:docker_url){ self.class.docker_url }
    @logger = options.fetch(:logger){ Cabin::Channel.get }
  end

  def self.docker_url
    ENV.fetch('DOCKER_URL'.freeze, 'unix:///var/run/docker.sock')
  end

  def request(*path)
    req = FTW::Request.new
    req.request_uri = ['', 'v1.9',*path].join('/')
    req.headers.set('Host',host)
    req.method = 'GET'
    req.port = port if port
    if block_given?
      yield req
      logger.debug("Sending request", path: req.path)
      return agent.execute(req)
    end
    return req
  end

  def read(name, resource)
    return to_enum(:read, name, resource) unless block_given?
    body = JSON.generate({'Resource' => resource})
    @logger.debug("Send", body: body)
    req = request('containers',name,'copy')
    req.method = 'POST'
    req.headers.set('Content-Type','application/json')
    req.headers.set('Content-Length',body.bytesize)
    req.body = body
    res = agent.execute(req)
    raise res.status.to_s if res.status != 200
    sio = StringIO.new(res.read_body)
    tar = ::Gem::Package::TarReader.new( sio )
    tar.each do |entry|
      yield entry
    end
  end

  def copy(name, resource, to)
    dest = File.dirname(to)
    read(name, resource) do | entry |
      extract_entry(dest, entry)
    end
  end

  def extract_entry(destdir, entry)
    full_name = entry.full_name
    mode = entry.header.mode

    dest = File.join(destdir, full_name)
    uid = map_user(entry.header.uid, entry.header.uname)
    gid = map_group(entry.header.gid, entry.header.gname)

    @logger.debug('Extracting','file' => dest, 'uid'=> uid, 'gid' => gid, 'entry.fullname' => full_name, 'entry.mode' => mode )

    case(entry.header.typeflag)
    when "5" # Directory
      FileUtils.mkdir_p(dest, :mode => mode)
    when "2" # Symlink
      destdir = File.dirname(dest)
      FileUtils.mkdir_p(destdir, :mode => 0755)
      File.symlink( entry.header.linkname, dest )
    when "0" # File
      destdir = File.dirname(dest)
      FileUtils.mkdir_p(destdir, :mode => 0755)
      File.open(dest, "wb", entry.header.mode) do |os|
        loop do
          data = entry.read(4096)
          break unless data
          os.write(data)
        end
        os.fsync
      end
    else
      @logger.warn('Ignoring unknown tar entry',name: entry.full_name)
      return
    end
    FileUtils.chmod(entry.header.mode, dest)
    chown( uid, gid, dest )
  end

  def chown( uid, gid, path )
    FileUtils.chown( uid, gid, path ) if chown?
  rescue Errno::EPERM
    @logger.warn('Unable to chown file', 'file' => path, 'uid' => uid, 'gid' => gid)
  end

  def chown?
    return true
  end

  def map_user( uid, _ )
    return uid
  end

  def map_group( gid, _ )
    return gid
  end



  def agent
    @agent ||= agent_for(docker_url)
  end

  def host
    @host ||= host_for(docker_url)
  end

  def port
    @port = port_for(docker_url) unless defined? @port
    @port
  end

  def agent_for( uri )
    proto, address = uri.split('://',2)
    case(proto)
    when 'unix'
      return FTW::SocketAgent.new(address)
    when 'tcp'
      return agent_for('http://' + address)
    when 'http', 'https'
      return FTW::Agent.new
    end
  end

  def host_for( uri )
    proto, address = uri.split('://',2)
    case (proto)
    when 'unix'
      return address
    else
      Addressable::URI.parse(uri).host
    end
  end

  def port_for( uri )
    proto, address = uri.split('://',2)
    case (proto)
    when 'unix'
      return nil
    else
      Addressable::URI.parse(uri).port
    end
  end

end
