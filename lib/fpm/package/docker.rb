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
    if client.broken_symlinks?
      changes = changes(name)
      leaves = Hash[ changes.leaves.map{|k| [k,true] } ]
      exclude_non_leaves = lambda{|x|
        !leaves.key?(x) }
      directories = changes.smallest_superset
      directories.each do |chg|
        copy(name, chg, only: leaves)
      end
    else
      leaves = changes(name).leaves
      leaves.each do |chg|
        copy(name, chg)
      end
    end
  end

private

  def client
    @client ||= FPM::Dockery::Client.new(logger: @logger)
  end

  def changes(name)
    fs = Node.read(client.changes(name))
    fs.reject!(&method(:ignore?))
    return fs
  end

  def copy(name, chg, options = {})
    client.copy(name, chg, staging_path(chg), {chown: false}.merge(options))
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
        children.each do |name, cld|
          cld.leaves( File.join(prefix,name), &block )
        end
      end
      return self
    end

    def contains_leaves?
      children.any?{|_,c| c.leaf? }
    end

    def smallest_superset( prefix = '/', &block )
      return to_enum(:smallest_superset, prefix) unless block
      if leaf?
        return
      elsif contains_leaves?
        yield prefix
      else
        children.each do |name, cld|
          cld.smallest_superset( File.join(prefix,name), &block)
        end
      end
    end

    def reject!( prefix = '/',&block )
      children.reject! do |name, cld| 
        p = File.join(prefix,name)
        if yield p
          true
        else
          cld.reject!(p,&block)
          false
        end
      end
    end

    def self.read(enum)
      fs = Node.new
      enum.each do |ch|
        n = fs
        ch['Path'].split('/').each do |part|
          n = n[part]
        end
      end
      return fs
    end
  end

end

