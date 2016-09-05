require 'excon'
require 'rubygems/package'
require 'json'
require 'fileutils'
require 'forwardable'
require 'fpm/fry/tar'

module FPM; module Fry; end ; end

class FPM::Fry::Client

  class FileNotFound < StandardError
  end

  extend Forwardable
  def_delegators :agent, :post, :get, :delete

  attr :docker_url, :logger, :tls

  def initialize(options = {})
    @docker_url = options.fetch(:docker_url){ self.class.docker_url }
    @logger = options[:logger]
    if @logger.nil?
      @logger = Cabin::Channel.get
    end
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

  def server_version
    @server_version ||= begin
      res = agent.get(
        expects: [200],
        path: '/version'
      )
      JSON.parse(res.body)
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
    ['', "v"+server_version['ApiVersion'],*path].join('/')
  end

  def read(name, resource)
    return to_enum(:read, name, resource) unless block_given?
    res = agent.get(
      path: url('containers',name,'archive'),
      query: URI.encode_www_form('path' => resource),
      headers: { 'Content-Type' => 'application/json' },
      expects: [200,404,500]
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

  def copy(name, resource, map, options = {})
    ex = FPM::Fry::Tar::Extractor.new(logger: @logger)
    base = File.dirname(resource)
    read(name, resource) do | entry |
      file = File.join(base, entry.full_name).chomp('/')
      file = file.sub(%r"\A\./",'')
      to = map[file]
      next unless to
      @logger.debug("Copy",name: file, to: to)
      ex.extract_entry(to, entry, options)
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
