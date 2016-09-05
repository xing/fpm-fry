require 'cabin'
class Cabin::NiceOutput

  CODEMAP = {
    :normal => "\e[0m",
    :red => "\e[1;31m",
    :green => "\e[1;32m",
    :yellow => "\e[0;33m",
    :white => "\e[0;37m",
    :blue => "\e[1;34m"
  }

  DIM_CODEMAP = {
    red:   "\e[0;31m",
    green: "\e[0;32m",
    white: "\e[1;30m",
    yellow: "\e[33m",
    blue: "\e[0;34m"
  }

  LEVELMAP = {
    :fatal => :red,
    :error => :red,
    :warn => :yellow,
    :info => :green,
    :hint => :blue,
    :debug => :white,
  }

  attr :io

  def initialize(io)
    @io = io
  end

  def <<(event)
    data = event.clone
    if data[:exception].respond_to? :data
      ed = data[:exception].data
      if ed.kind_of? Hash
        data = ed.merge( data )
      else
        data[:exception_data] = ed.inspect
      end
    end
    data.delete(:line)
    data.delete(:file)
    level = data.delete(:level) || :normal
    data.delete(:message)
    ts = data.delete(:timestamp)

    color = data.delete(:color)
    # :bold is expected to be truthy
    bold = data.delete(:bold) ? :bold : nil

    backtrace = data.delete(:backtrace)
    if !backtrace && data[:exception].respond_to?(:backtrace)
      backtrace = data[:exception].backtrace
    end

    # Make 'error' and other log levels have color
    if color.nil?
      color = LEVELMAP[level]
    end

    message = [event[:level] ? '====> ' : '      ',event[:message]]
    message.unshift(CODEMAP[color.to_sym]) if !color.nil?
    message << DIM_CODEMAP[color] if !color.nil?
    if documentation = data.delete(:documentation)
      message << "\n\tRead more on this topic here: #{documentation}"
    end
    if data.any?
      message << "\n" <<  pp(data)
    end
    if backtrace
      message << "\n\t--backtrace---------------\n\t" << backtrace.join("\n\t")
    end
    message << CODEMAP[:normal]  if !color.nil?
    @io.puts(message.join(""))
    @io.flush
  end

  def pp(hash)
    hash.map{|k,v| '      '+k.to_s + ": " + v.inspect }.join("\n")
  end

end
