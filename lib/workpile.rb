require 'drb/drb'
module Workpile
  class Service
    def initialize
      @queue = Queue.new
      @pids = []
    end
    
    def pop
      @queue.pop
    end
    
    def push(obj)
      @queue.push obj
    end
    
    def add_working_client(pid)
      @pids << pid
    end

    def remove_working_client(pid)
      @pids -= [pid]
    end
    
    def kill_working_children
      return if @pids.empty?
      s1 = @pids.map{|pid| " /PID #{pid} " }
      IO.popen("start /b taskkill /F #{s1}")
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
          loop { system("#{cmd} #{DRb.uri} #{index}") }
        end
      end
    end

    def kill_working_children
      @service.kill_working_children
    end
  end

  class Child
    attr_accessor :index
    def initialize(index = ARGV.pop, uri = ARGV.pop)
      @index = index
      @service = DRbObject.new_with_uri(uri)
    end
    
    def wait_request
      req = @service.pop
      @service.add_working_client(Process.pid)
      at_exit do
        @service.remove_working_client(Process.pid)
      end
      req
    end
  end
end
