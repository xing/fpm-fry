require 'fpm/fry/plugin'
module FPM::Fry::Plugin ; 

  # Allows adding a debian repository.
  #
  # @note experimental
  #
  # @example in a recipe
  #   plugin 'apt' do |apt|
  #     apt.repository "https://repo.varnish-cache.org/#{distribution}", "trusty", "varnish-4.1"
  #   end
  #
  class Apt

  # Adds a debian repository
  #
  # @param [String] url
  # @param [String] distribution
  # @param [String,Array<String>] components
  # @param [Hash] options
  def repository(url, distribution, components, options = {} )
    name = "#{url}-#{distribution}".gsub(/[^a-zA-Z0-9_\-]/,'-')
    source = ['deb']
    source << '[trusted=yes]'
    source << url
    source << distribution
    source << Array(components).join(' ')
    @builder.before_dependencies do
      @builder.bash "echo '#{source.join(' ')}' >> /etc/apt/sources.list.d/#{name}.list && apt-get update -o Dir::Etc::sourcelist='sources.list.d/#{name}.list' -o Dir::Etc::sourceparts='-' -o APT::Get::List-Cleanup='0'"
    end
  end

  def self.apply(builder, &block)
    if builder.flavour != "debian"
      builder.logger.info('skipped apt plugin')
      return
    end
    dsl = self.new(builder)
    if block.arity == 1
      block.call(dsl)
    else
      dsl.instance_eval(&block)
    end
  end

  private

  def initialize(builder)
    @builder = builder
  end

end ; end
