module FPM::Fry
  # Helper class for filesystem operations inside staging directory.
  # Resolves all symlinks relativ to a given base directory.
  class Chroot

    attr :base

    # @param [String] base filesystem base
    def initialize(base)
      raise ArgumentError, "Base #{base.inspect} is not a directory" unless File.directory? base
      @base = base
    end

    # @param [String] dir
    # @result [Array<String>] entries
    def entries(dir)
      dir = rebase(dir)
      return Dir.entries(dir)
    end

    # @param [String] file
    # @see (File.open)
    def open(file,*args,&block)
      file = rebase(file)
      return File.open(file,*args,&block)
    end

    # @param [String] dir
    # @yields entry
    # @yieldparam [String] entry
    def find(dir, &block)
      if stat(dir).directory?
        entries(dir).each do | e |
          next if e == "."
          next if e == ".."
          path = File.join(dir,e)
          catch(:prune) do
            block.call(path)
            find(path, &block)
          end
        end
      else
        block.call(dir)
      end
      return nil
    end

    # @param [String] file
    # @return [File::Stat] stat
    # @see (File.lstat)
    def lstat(file)
      File.lstat(rebase(file, FOLLOW_ALL_BUT_LAST))
    end

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
            end
            segs.unshift *rl.split('/')
          end
        end
      end
      return [base,*current].join('/')
    end


  end
end
