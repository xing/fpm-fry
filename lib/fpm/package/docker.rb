require 'fpm'
require 'fpm/package'
require 'rubygems/package'
require 'ftw/request'
require 'ftw/connection'
require 'ftw/socket_connection'
require 'ftw/socket_agent'
require 'json'

class FPM::Package::Docker < FPM::Package

  def input(name)
    leaves = changes(name)
    leaves.each do |chg|
      next if ignore? chg
      copy(name, chg)
    end
  end

private

  def changes(name)
    req = request('containers',name,'changes')
    req.method = 'GET'
    res = agent.execute(req)
    raise res.status.to_s if res.status != 200
    changes = JSON.parse(res.read_body)
    return change_leaves(changes)
  end

  def copy(name, resource)
    body = JSON.generate({'Resource' => resource})
    @logger.debug("Send", body: body)
    req = request('containers',name,'copy')
    req.method = 'POST'
    req.headers.set('Content-Type','application/json')
    req.headers.set('Content-Length',body.bytesize)
    req.body = body
    res = agent.execute(req)
    raise res.status if res.status != 200
    sio = StringIO.new(res.read_body)
    unpack(sio, resource)
  end

  def request(*path)
    req = FTW::Request.new
    req.request_uri = ['', 'v1.9',*path].join('/')
    req.headers.set('Host',host)
    req.port = port if port
    return req
  end

  def docker_url
    ENV.fetch('DOCKER_URL'.freeze, 'unix:///var/run/docker.sock')
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
  def ignore?(chg)
    [
      '/dev','/dev/**/*', '/tmp','/tmp/**/*','/**/.bash_history'
    ].any?{|pattern| File.fnmatch?(pattern, chg, ::File::FNM_PATHNAME) }
  end

  def unpack( io , as , &block )
    dest = File.dirname(staging_path(as).to_s)
    tar = ::Gem::Package::TarReader.new( io )
    tar.each do |entry|
      extract_entry(dest, entry, &block)
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

  class Node < Struct.new(:children)

    def initialize
      super(Hash.new{|hsh,key| hsh[key] = Node.new })
    end

    def [](name)
      children[name]
    end

    def leaf?
      children.none?
    end

    def leaves( prefix = '/', &block )
      return to_enum(:leaves, prefix) unless block
      if leaf?
        yield prefix
      else
        children.each do |name, cld|
          cld.leaves( File.join(prefix,name), &block )
        end
      end
      return self
    end

  end

  def change_leaves( changes, &block )
    fs = Node.new
    changes.each do |ch|
      n = fs
      ch['Path'].split('/').each do |part|
        n = n[part]
      end
    end
    return fs.leaves(&block)
  end

end

