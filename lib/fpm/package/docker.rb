require 'fpm'
require 'fpm/package'

require 'fpm/dockery/client'

class FPM::Package::Docker < FPM::Package

  def input(name)
    leaves = changes(name)
    leaves.each do |chg|
      next if ignore? chg
      copy(name, chg)
    end
  end

private

  def client
    @client ||= FPM::Dockery::Client.new(logger: @logger)
  end

  def copy(name, chg)
    client.copy(name, chg, staging_path(chg))
  end

  def changes(name)
    req = client.request('containers',name,'changes')
    req.method = 'GET'
    res = client.agent.execute(req)
    raise res.status.to_s if res.status != 200
    changes = JSON.parse(res.read_body)
    return change_leaves(changes)
  end

  def ignore?(chg)
    [
      '/dev','/dev/**/*', '/tmp','/tmp/**/*','/**/.bash_history'
    ].any?{|pattern| File.fnmatch?(pattern, chg, ::File::FNM_PATHNAME) }
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

