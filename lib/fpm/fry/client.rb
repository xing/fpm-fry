require 'cabin'
require 'excon'
require 'rubygems/package'
require 'json'
require 'fileutils'
require 'forwardable'
require 'fpm/fry/tar'
require 'fpm/fry/with_data'
class FPM::Fry::Client

  # Raised when a file wasn't found inside a container
  class FileNotFound < StandardError
    include FPM::Fry::WithData
  end

  # Raised when a container wasn't found.
  class ContainerNotFound < StandardError
    include FPM::Fry::WithData
  end

  # Raised when trying to read file that can't be read e.g. because it's a
  # directory.
  class NotAFile < StandardError
    include FPM::Fry::WithData
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

  # @return [String] docker server api version
  def server_version
    @server_version ||=
      begin
        res = agent.get(
          expects: [200],
          path: '/version'
        )
        JSON.parse(res.body)
      rescue Excon::Error => e
        @logger.error("could not read server version: url: /version, errorr #{e}")
        raise
      end
  end

  # @return [String] docker cert path from environment
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
    ['', "v"+server_version['ApiVersion'], *path.compact].join('/')
  end

  def read(name, resource)
    return to_enum(:read, name, resource) unless block_given?
    url = nil
    res = begin
            if (server_version['ApiVersion'] < "1.20")
              url = self.url('containers', name, 'copy')
              agent.post(
                path: url,
                headers: { 'Content-Type' => 'application/json' },
                body: JSON.generate({'Resource' => resource}),
                expects: [200,404,500]
              )
            else
              url = self.url('containers', name, 'archive')
              agent.get(
                path: url,
                headers: { 'Content-Type' => 'application/json' },
                query: {:path => resource},
                expects: [200,404,500]
              )
            end
          rescue Excon::Error => e
            @logger.error("unexpected response when reading resource: url: #{url}, error: #{e}")
            raise
          end
    if [404,500].include? res.status
      body_message = Hash[JSON.load(res.body).map{|k,v| ["docker.#{k}",v] }] rescue {'docker.message' => res.body}
      body_message['docker.container'] = name
      if body_message['docker.message'] =~ /\ANo such container:/
        raise ContainerNotFound.new("container not found", body_message)
      end
      raise FileNotFound.new("file not found", {'path' => resource}.merge(body_message))
    end
    sio = StringIO.new(res.body)
    tar = FPM::Fry::Tar::Reader.new( sio )
    tar.each do |entry|
      yield entry
    end
  end

  # Gets the file contents while following symlinks
  # @param [String] name the container name
  # @param [String] resource the file name
  # @return [String] content
  # @raise [NotAFile] when the file has no readable content
  # @raise [FileNotFound] when the file does not exist
  # @api docker
  def read_content(name, resource)
    read(name, resource) do |file|
      if file.header.typeflag == "2"
        return read_content(name, File.absolute_path(file.header.linkname,File.dirname(resource)))
      end
      if file.header.typeflag != "0"
        raise NotAFile.new("not a file", {'path' => resource})
      end
      return file.read
    end
  end

  # Gets the target of a symlink
  # @param [String] name the container name
  # @param [String] resource the file name
  # @return [String] target
  # @return [nil] if resource is not a symlink
  # @api docker
  def link_target(name, resource)
    read(name, resource) do |file|
      if file.header.typeflag == "2"
        return File.absolute_path(file.header.linkname,File.dirname(resource))
      end
      return nil
    end
    return nil
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
    url = url('containers',name,'changes')
    res = agent.get(path: url, expects: [200, 204])
    return JSON.parse(res.body)
  rescue Excon::Error => e
    @logger.error("could not retrieve changes for: #{name}, url: #{url}, error: #{e}")
    raise
  end

  def pull(image)
    agent.post(path: url('images','create'), query: {'fromImage' => image})
  end

  def create(image)
    url = url('containers','create')
    res = agent.post(
      headers: { 'Content-Type' => 'application/json' },
      path: url,
      body: JSON.generate('Image' => image)
    )
    return JSON.parse(res.body)['Id']
  rescue Excon::Error => e
    @logger.error("could not create image: #{image}, url: #{url}, error: #{e}")
    raise
  end

  def destroy(container)
    return unless container
    url = self.url('containers', container)
    agent.delete(
      path: url,
      expects: [204]
    )
  rescue Excon::Error => e
    @logger.error("could not destroy container: #{container}, url: #{url}, error: #{e}")
    raise
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
      options[:host] = ""
      options[:hostname] = ""
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
