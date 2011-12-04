$stdout.sync = true
Thread.abort_on_exception = true

puts "booting..."

require 'rubygems'
require 'rspec'

require 'workpile'
cl = Workpile::Child.new

class GemfileBox
  class << self
    def source(*arg)
    end
    def gem(name, *hash)
      if hash[0] and hash[0][:require]
        require hash[0][:require]
      else
        require name
      end
      rescue LoadError
        nil
    end
    def group(sym, &block)
      block.call
    end
    def gemspec(*a)
    end
  end
  instance_eval IO.read("./gemfile") if File.exists?("./gemfile")
end

puts "ready"

str = cl.wait_request

args = str.split(" ")
src = args[-1]

if not File.exists?(src)
  puts "Spec File Not Find(#{src})"
  exit
end

case src
when ":exit"
  exit
else
  puts "load #{src}"
end

begin
  RSpec::Core::Runner.disable_autorun!
  RSpec::Core::Runner.run( [src], STDERR, STDOUT)
rescue Exception
  puts "#{$!}"
  puts $!.backtrace
end
