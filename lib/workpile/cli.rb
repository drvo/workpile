require "rubygems"
require "fssm"

$stdout.sync = true
Thread.abort_on_exception = true

require 'workpile'
class FSSMGuard
  def initialize
    @watch = {}
  end
  
  def guard(&proc)
    instance_exec &proc
    _self = self
    Thread.new do
      FSSM.monitor(".") do
        update{|base,relative| _self.event(base,relative); }
        delete{|base,relative| _self.event(base,relative); }
        create{|base,relative| _self.event(base,relative); }
      end
    end
    $stdin.gets
    on_exit
  end
  
  def watch(regexp, &block)
    @watch[regexp] = block
  end
  
  def event(base, relative)
    @watch.keys.each do |regexp|
      if m = ( relative.match(regexp) )
        invoke(@watch[regexp] ? @watch[regexp].call(m) : relative)
      end
    end
  end
  
  def invoke(fname)
    system(fname)
  end
  
  def on_exit
  end
end

class RSpecGuard < FSSMGuard
  def initialize
    super
    @parent = Workpile::Parent.new
    @parent.spawn_children(3, "ruby #{File.dirname(__FILE__) + "\\workpile_rspec.rb"}")
  end
  
  def invoke(fname)
    @parent.request(fname)
  end
  
  def on_exit
    puts "workpile process shutdown..."
    @parent.abort
  end
end

RSpecGuard.new.guard do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

  # Rails example
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/acceptance/#{m[1]}_spec.rb"] }
  watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
  watch('spec/spec_helper.rb')                        { "spec" }
  watch('config/routes.rb')                           { "spec/routing" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }
  # Capybara request specs
  watch(%r{^app/views/(.+)/.*\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }
end
