require "rubygems/package"
require 'fpm/fry/channel'

module FPM; module Fry; end ; end

class FPM::Fry::Tar

  class Reader
    include Enumerable

    def initialize(io)
      @reader = Gem::Package::TarReader.new(io)
    end

    def each
      return to_enum(:each) unless block_given?

      last_pax_header = nil
      @reader.each do |entry|
        if entry.header.typeflag == 'x'
          last_pax_header = extract_pax_header(entry.read)
        else
          if last_pax_header && (path = last_pax_header["path"])
            entry.header.instance_variable_set :@name, path
            last_pax_header = nil
          end
          yield entry
        end
      end
    end

    def map
      return to_enum(:map) unless block_given?

      res = []
      each do |entry|
        res << yield(entry)
      end
      res
    end

    private

    def extract_pax_header(string)
      res = {}
      s = StringIO.new(string)
      while !s.eof?
        total_len = 0
        prefix_len = 0
        # read number prefix and following blank
        while (c = s.getc) && (c =~ /\d/)
          total_len = 10 * total_len + c.to_i
          prefix_len += 1
        end
        field = s.read(total_len - prefix_len - 2)
        if field =~ /\A([^=]+)=(.+)\z/
          res[$1] = $2
        else
          raise "malformed pax header: #{field}"
        end
        s.read(1) # read trailing newline
      end
      res
    end

  end

  class Extractor

    def initialize( options = {} )
      @logger = options.fetch(:logger){ Cabin::Channel.get }
    end 

    def extract(destdir, reader, options = {})
      reader.each do |entry|
        extract_entry(File.join(destdir, entry.full_name), entry, options)
      end
    end

    def extract_entry(dest, entry, options = {})
      full_name = entry.full_name
      mode = entry.header.mode

      destdir = File.dirname(dest)
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
            os.write(data)
          end
          os.fsync
        end
      else
        @logger.warn('Ignoring unknown tar entry',name: full_name)
        return
      end
      FileUtils.chmod(entry.header.mode, dest)
      chown( uid, gid, dest ) if options.fetch(:chown,true)
    end

    def chown( uid, gid, path )
      FileUtils.chown( uid, gid, path )
    rescue Errno::EPERM
      @logger.warn('Unable to chown file', 'file' => path, 'uid' => uid, 'gid' => gid)
    end

    def map_user( uid, _ )
      return uid
    end

    def map_group( gid, _ )
      return gid
    end

  end

end


