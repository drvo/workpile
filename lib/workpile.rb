require 'drb/drb'
module Workpile
  class Service
    attr_accessor :boot_pids, :working_pids

    def initialize
      @queue = Queue.new
      @working_pids = []
      @boot_pids = []
    end
    
    def pop
      @queue.pop
    end
    
    def push(obj)
      @queue.push obj
    end
    
    def kill_working_children
      p @working_pids
      return if @working_pids.empty?
      s1 = @working_pids.map{|pid| " /PID #{pid} " }
      IO.popen("start /b taskkill /F #{s1}")
      @working_pids.clear
    end
    
    def kill
      s1 = @boot_pids.map{|pid| " /PID #{pid} " }
      IO.popen("start /b taskkill /F #{s1}")
      @boot_pids.clear
      @pids.clear
    end
  end

  class Parent
    def initialize
      @service = Service.new
      DRb.start_service('druby://127.0.0.1:0',@service)
    end
    
    def request(obj)
      @service.push obj
    end
    
    def spawn_children(n, cmd)
      n.times.map do |index|
        Thread.new do
          loop {
            system("#{cmd} #{DRb.uri} #{index}")
          }
        end
      end
    end

    def kill_working_children
      @service.kill_working_children
    end
    
    def kill
      @service.kill
    end
  end

  class Child
    attr_accessor :index
    def initialize(index = ARGV.pop, uri = ARGV.pop)
      @index = index
      @service = DRbObject.new_with_uri(uri)
      @service.boot_pids.push Process.pid
    end
    
    def wait_request
      req = @service.pop
      @service.working_pids.push Process.pid
      at_exit do
        @service.working_pids -= [Process.pid]
        @service.boot_pids -= [Process.pid]
      end
      req
    end
  end
end
