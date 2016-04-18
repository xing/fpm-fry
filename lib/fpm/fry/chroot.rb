require 'fpm/fry/with_data'
module FPM ; module Fry
  # Helper class for filesystem operations inside staging directory.
  # Resolves all symlinks relativ to a given base directory.
  class Chroot

    attr :base

    # @param [String] base filesystem base
    def initialize(base)
      raise ArgumentError, "Base #{base.inspect} is not a directory" unless File.directory? base
      @base = base
    end

    # Returns all directory entries like Dir.entries.
    # @param [String] path
    # @result [Array<String>] entries
    def entries(path)
      dir = rebase(path)
      return Dir.entries(dir)
    rescue => ex
      raise Fry::WithData(ex, path: path)
    end

    # Opens a file like File.open.
    # @param [String] path
    # @see (File.open)
    def open(path,*args,&block)
      file = rebase(path)
      return File.open(file,*args,&block)
    rescue => ex
      raise Fry::WithData(ex, path: path)
    end

    # Yields all entries recursively like Find.find.
    # @param [String] path
    # @yields entry
    # @yieldparam [String] entry
    def find(path, &block)
      if stat(path).directory?
        catch(:prune) do
          block.call(path)
          entries(path).each do | e |
            next if e == "."
            next if e == ".."
            ep = File.join(path,e)
            find(ep, &block)
          end
        end
      else
        block.call(path)
      end
      return nil
    end

    # Stats a file without following the last symlink like File.lstat.
    # @param [String] file
    # @return [File::Stat] stat
    # @see (File.lstat)
    def lstat(file)
      File.lstat(rebase(file, FOLLOW_ALL_BUT_LAST))
    end

    # Stats a file like File.stat.
    # @param [String] file
    # @return [File::Stat] stat
    # @see (File.stat)
    def stat(file)
      File.stat(rebase(file))
    end

   private

    FOLLOW = lambda do |base, current, rest|
      path = [base, *current].join('/')
      if File.symlink?(path)
        File.readlink(path)
      else
        nil
      end
    end

    FOLLOW_ALL_BUT_LAST = lambda do |base, current, rest|
      if rest.any?
        FOLLOW.call(base, current, rest)
      else
        nil
      end
    end

    def rebase(path, symlink_strategy = FOLLOW)
      segs = path.split('/')
      current = []
      while segs.any?
        seg = segs.shift
        case seg
        when '', '.' then next
        when '..' then
          # We don't check if anything was actually removed.
          # This is consistent with File/Dir behavior.
          current.pop
        else
          current << seg
          rl = symlink_strategy.call(base, current, segs)
          if rl
            if rl.start_with? '/'
              current = []
            else
              current.pop
            end
            segs.unshift *rl.split('/')
          end
        end
      end
      return [base,*current].join('/')
    end

  end
end ; end
