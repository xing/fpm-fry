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
      next unless only[ File.join(base, entry.full_name) ]
      ex.extract_entry(dest, entry, options)
    end
  end

  def changes(name)
    res = agent.get(path: url('containers',name,'changes'))
    raise res.reason if res.status != 200
    return JSON.parse(res.body)
  end

  def agent
    @agent ||= agent_for(docker_url)
  end

  def broken_symlinks?
    return true
  end

  def agent_for( uri )
    proto, address = uri.split('://',2)
    case(proto)
    when 'unix'
      return Excon.new("unix:///", socket: address, instrumentor: LogInstrumentor.new(logger), read_timeout: 10000)
    when 'tcp'
      return agent_for("http://#{address}")
    when 'http', 'https'
      return Excon.new(uri, instrumentor: LogInstrumentor.new(logger), read_timeout: 10000)
    end
  end
end
