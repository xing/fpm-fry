module FPM; module Dockery; end ; end

class FPM::Dockery::Tar

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


