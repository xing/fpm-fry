require 'excon'
require 'rubygems/package'
require 'json'
require 'fileutils'
require 'forwardable'
require 'fpm/dockery/tar'

module FPM; module Dockery; end ; end

class FPM::Dockery::Client

  class LogInstrumentor < Struct.new(:logger)

    def instrument(event, data = {})
      if block_given?
        logger.debug('Requesting HTTP', filtered(data))
        r = yield
        return r
      else
        logger.debug('Getting HTTP response', filtered(data))
      end
    end

    def filtered(data)
      filtered = {}
      filtered[:path] = data[:path] if data[:path]
      filtered[:verb] = data[:method] if data[:method]
      filtered[:status] = data[:status] if data[:status]
      filtered[:body] = data[:body][0..500] if data[:body]
      filtered[:headers] = data[:headers] 
      return filtered
    end

  end

  class FileNotFound < StandardError
  end

  extend Forwardable
  def_delegators :agent, :post, :get, :delete

  attr :docker_url, :logger, :tls

  def initialize(options = {})
    @docker_url = options.fetch(:docker_url){ self.class.docker_url }
    @logger = options.fetch(:logger){ Cabin::Channel.get }
    if options[:tls].nil? ? docker_url =~ %r!(\Ahttps://|:2376\z)! : options[:tls]
      # enable tls
      @tls = {
        client_cert: File.join(self.class.docker_cert_path,'cert.pem'),
        client_key: File.join(self.class.docker_cert_path, 'key.pem'),
        ssl_ca_file: File.join(self.class.docker_cert_path, 'ca.pem'),
        ssl_verify_peer: options.fetch(:tlsverify){ false }
      }
      [:client_cert, :client_key, :ssl_ca_file].each do |k|
        if !File.exists?(@tls[k])
          raise ArgumentError.new("#{k} #{@tls[k]} doesn't exist. Did you set DOCKER_CERT_PATH correctly?")
        end
      end
    else
      @tls = {}
    end
  end

  def self.docker_cert_path
    ENV.fetch('DOCKER_CERT_PATH',File.join(Dir.home, '.docker'))
  end

  def self.docker_url
    ENV.fetch('DOCKER_HOST'.freeze, 'unix:///var/run/docker.sock')
  end

  def tls?
    tls.any?
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
      raise FileNotFound, "File #{resource.inspect} not found: #{res.body}"
    end
    sio = StringIO.new(res.body)
    tar = ::Gem::Package::TarReader.new( sio )
    tar.each do |entry|
      yield entry
    end
  end

  def copy(name, resource, to, options = {})
    dest = File.dirname(to)
    ex = FPM::Dockery::Tar::Extractor.new(logger: @logger)
    case(options[:only])
    when Hash
      only = options[:only]
    when Array
      only = Hash[ options[:only].map{|k| [k,true] } ]
    else
      only = Hash.new{ true }
    end
    base = File.dirname(resource)
    read(name, resource) do | entry |
      next unless only[ File.join(base, entry.full_name).chomp('/') ]
      ex.extract_entry(dest, entry, options)
    end
  end

  def changes(name)
    res = agent.get(path: url('containers',name,'changes'))
    raise res.reason if res.status != 200
    return JSON.parse(res.body)
  end

  def agent
    @agent ||= agent_for(docker_url, tls)
  end

  def broken_symlinks?
    return true
  end

  def agent_for( uri, tls )
    proto, address = uri.split('://',2)
    options = {
      instrumentor: LogInstrumentor.new(logger),
      read_timeout: 10000
    }.merge( tls )
    case(proto)
    when 'unix'
      uri = "unix:///"
      options[:socket] = address
    when 'tcp'
      if tls.any?
        return agent_for("https://#{address}", tls)
      else
        return agent_for("http://#{address}", tls)
      end
    when 'http', 'https'
    end
    logger.debug("Creating Agent", options.merge(uri: uri))
    return Excon.new(uri, options)
  end
end
