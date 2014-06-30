require 'fpm'
require 'fpm/package'

require 'fpm/dockery/client'

class FPM::Package::Docker < FPM::Package

  def initialize( options = {} )
    super()
    if options[:logger]
      @logger = options[:logger]
    end
    if options[:client]
      @client = options[:client]
    end
  end

  def input(name)
    leaves = change_leaves(client.changes(name))
    leaves.each do |chg, is_dir|
      next false if ignore? chg
      copy(name, chg) if !is_dir
    end
  end

private

  def client
    @client ||= FPM::Dockery::Client.new(logger: @logger)
  end

  def copy(name, chg)
    client.copy(name, chg, staging_path(chg), chown: false)
  end

  IGNORED_PATTERNS = [
    %r!\A/dev(/|\z)!,%r!\A/tmp(/|\z)!,'/root/.bash_history','/.bash_history'
  ]

  def ignore?(chg)
    return true if IGNORED_PATTERNS.any?{|pattern| pattern === chg }
    Array(attributes[:excludes]).each do |wildcard|
      if File.fnmatch(wildcard, chg) || File.fnmatch(wildcard, chg[1..-1])
        return true
      end
    end
    return false
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
        yield prefix, false
      else
        c = yield prefix, true
        if c != false
          children.each do |name, cld|
            cld.leaves( File.join(prefix,name), &block )
          end
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

