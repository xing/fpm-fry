require 'fpm/fry/detector'
module FPM; module Fry

  module Detector
    # Detects a set of basic properties about an image.
    #
    # @param [Inspector] inspector
    # @return [Hash<Symbol, String>]
    def self.detect(inspector)
      found = {}
      if inspector.exists? '/usr/bin/apt-get'
        found[:flavour] = 'debian'
      elsif inspector.exists? '/bin/rpm'
        found[:flavour] = 'redhat'
      end
      begin
        inspector.read_content('/etc/lsb-release').each_line do |line|
          case(line)
          when /\ADISTRIB_ID=/ then
            found[:distribution] = $'.strip.downcase
          when /\ADISTRIB_RELEASE=/ then
            found[:release] = $'.strip
          when /\ADISTRIB_CODENAME=/ then
            found[:codename] = $'.strip
          end
        end
      rescue Client::FileNotFound
      end

      begin
        inspector.read_content('/etc/os-release').each_line do |line|
          case(line)
          when /\AVERSION=\"(\w+) \((\w+)\)\"/ then
            found[:release] ||= $1
            found[:codename] ||= $2
          end
        end
      rescue Client::FileNotFound
      end
      begin
        content = inspector.read_content('/etc/debian_version')
        if /\A\d+(?:\.\d+)+\Z/ =~ content
          found[:distribution] ||= 'debian'
          found[:release] = content.strip
        end
      rescue Client::FileNotFound
      end
      begin
        content = inspector.read_content('/etc/redhat-release')
        content.each_line do |line|
          case(line)
          when /\A(\w+)(?: Linux)? release ([\d\.]+)/ then
            found[:distribution] ||= $1.strip.downcase
            found[:release] = $2.strip
          end
        end
      rescue Client::FileNotFound
      end
      return found
    end
  end
end ; end
