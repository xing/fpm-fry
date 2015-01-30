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
    if @logger.nil?
      @logger = Cabin::Channel.get
    end
  end

  def input(name)
    changes = changes(name)
    changes.remove_modified_leaves! do | ml |
      @logger.warn("Found a modified file. You can only create new files in a package",file: ml)
    end
    leaves = Hash[ changes.leaves.map{|k| [k,true] } ]
    directories = changes.smallest_superset
    directories.each do |chg|
      copy(name, chg, only: leaves)
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

  class Node < Struct.new(:children, :kind)

    def initialize
      super(Hash.new{|hsh,key| hsh[key] = Node.new },nil)
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

    def modified_leaves( prefix = '/', &block )
      return to_enum(:modified_leaves, prefix) unless block
      if leaf?
        if kind != 1
          yield prefix
        end
      else
        children.each do |name, cld|
          cld.modified_leaves( File.join(prefix,name), &block)
        end
      end
    end

    def remove_modified_leaves!( prefix = '/', &block )
      to_remove = {}
      children.each do |name, cld|
        removed_children = cld.remove_modified_leaves!(File.join(prefix,name), &block)
        if cld.leaf? and cld.kind != 1
          to_remove[name] = removed_children
        end
      end
      if to_remove.any?
        to_remove.each do |name, removed_children|
          children.delete(name)
          if !removed_children
            yield File.join(prefix,name)
          end
        end
        return true
      end
      return false
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

    def delete(path)
      _, key, rest = path.split('/',3)
      if rest.nil?
        children.delete(key)
      else
        children[key].delete("/#{rest}")
      end
    end

    def self.read(enum)
      fs = Node.new
      enum.each do |ch|
        n = fs
        ch['Path'].split('/').each do |part|
          n = n[part]
        end
        n.kind = ch['Kind']
      end
      return fs
    end
  end

end

