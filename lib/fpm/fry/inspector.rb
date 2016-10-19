module FPM::Fry
  # An inspector allows a plugin to gather information about the image used to 
  # build a package.
  class Inspector

    # Gets the file content at path.
    #
    # @param [String] path path to a file
    # @raise [FPM::Fry::Client::FileNotFound] when the given path doesn't exist
    # @raise [FPM::Fry::Client::NotAFile] when the given path is not a file
    # @return [String] file content as string
    def read_content(path)
      return client.read_content(container, path)
    end

    # Gets whatever is at path. This once if path is a file. And all subfiles 
    # if it's a directory. Usually read_content is better.
    #
    # @param [String] path path to a file
    # @raise [FPM::Fry::Client::FileNotFound] when the given path doesn't exist
    # @raise [FPM::Fry::Client::NotAFile] when the given path is not a file
    # @yield [entry] tar file entry
    # @yieldparam entry [Gem::Package::TarEntry]
    def read(path, &block)
      return client.read(container, path, &block)
    end

    # Determines the target of a link
    #
    # @param [String] path
    # @raise [FPM::Fry::Client::FileNotFound] when the given path doesn't exist
    # @return [String] target
    # @return [nil] when file is not a link
    def link_target(path)
      return client.link_target(container, path)
    end

    # Checks if file exists at path
    #
    # @param [String] path
    # @return [true] when path exists
    # @return [false] otherwise
    def exists?(path)
      client.read(container,path) do
        return true
      end
    rescue FPM::Fry::Client::FileNotFound
      return false
    end

    def self.for_image(client, image)
      container = client.create(image)
      begin
        yield new(client, container)
      ensure
        client.destroy(container)
      end
    end

  private
    def initialize(client, container)
      @client, @container = client, container
    end

    attr :client
    attr :container

  end

end
