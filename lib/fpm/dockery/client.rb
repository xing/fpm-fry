require 'excon'
require 'rubygems/package'
require 'json'
require 'fileutils'
require 'forwardable'

module FPM; module Dockery; end ; end

class FPM::Dockery::Client

  class LogInstrumentor < Struct.new(:logger)

    def instrument(event, data = {})
      if block_given?
        logger.debug(event+'.before', filtered(data))
        r = yield
        logger.debug(event+'.after', filtered(data))
        return r
      else
        logger.debug(event, filtered(data))
      end
    end

    def filtered(data)
      filtered = {}
      filtered[:path] = data[:path]
      filtered[:verb] = data[:method]
      filtered[:headers] = data[:headers] 
      return filtered
    end

  end

  class FileNotFound < StandardError
  end

  extend Forwardable
  def_delegators :agent, :post, :get, :delete

  attr :docker_url, :logger

  def initialize(options = {})
    @docker_url = options.fetch(:docker_url){ self.class.docker_url }
    @logger = options.fetch(:logger){ Cabin::Channel.get }
  end

  def self.docker_url
    ENV.fetch('DOCKER_HOST'.freeze, 'unix:///var/run/docker.sock')
  end

  def url(*path)
    ['', 'v1.9',*path].join('/')
  end

  def read(name, resource)
    return to_enum(:read, name, resource) unless block_given?
    body = JSON.generate({'Resource' => resource})
    res = agent.post(
      path: url('containers',name,'copy'),
      headers: { 'Content-Type' => 'application/json' },
      body: body,
      expects: [200,500]
    )
    if res.status == 500
      raise FileNotFound
    end
    sio = StringIO.new(res.body)
    tar = ::Gem::Package::TarReader.new( sio )
    tar.each do |entry|
      yield entry
    end
  end

  def copy(name, resource, to, options = {})
    dest = File.dirname(to)
    read(name, resource) do | entry |
      extract_entry(dest, entry, options)
    end
  end

  def extract_entry(destdir, entry, options)
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
    chown( uid, gid, dest ) if options.fetch(:chown,true)
  end

  def chown( uid, gid, path )
    FileUtils.chown( uid, gid, path )
  rescue Errno::EPERM
    @logger.warn('Unable to chown file', 'file' => path, 'uid' => uid, 'gid' => gid)
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

  def url_base
    if host != ''
      "http://#{host}:#{port}"
    else
      'http://docker.sock'
    end
  end

  def host
    @host ||= host_for(docker_url)
  end

  def port
    @port = port_for(docker_url) unless defined? @port
    @port
  end

  class UNIXSocketFactory < Struct.new(:file)
    def open( *_ )
      UNIXSocket.new( file )
    end
  end

  def agent_for( uri )
    proto, address = uri.split('://',2)
    case(proto)
    when 'unix'
      return Excon.new("unix:///", socket: address, instrumentor: LogInstrumentor.new(logger))
    when 'tcp'
      return agent_for("http://#{address}")
    when 'http', 'https'
      return Excon.new(uri, instrumentor: LogInstrumentor.new(logger))
    end
  end

  def host_for( uri )
    proto, address = uri.split('://',2)
    case (proto)
    when 'unix'
      return ''#, address
    else
      URI.parse(uri).host
    end
  end

  def port_for( uri )
    proto, address = uri.split('://',2)
    case (proto)
    when 'unix'
      return nil
    else
      URI.parse(uri).port
    end
  end

end
