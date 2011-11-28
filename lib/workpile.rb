require 'drb/drb'
module Workpile
  class Service
    def initialize
      @queue = Queue.new
      @pids = []
      @boot_pids = []
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
    
    def add_boot_client(pid)
      @boot_pids << pid
    end

    def remove_boot_client(pid)
      @boot_pids -= [pid]
    end
    
    def kill_working_children
      return if @pids.empty?
      s1 = @pids.map{|pid| " /PID #{pid} " }
      IO.popen("start /b taskkill /F #{s1}")
      @pids.clear
    end
    
    def kill_boot_children
      return if @boot_pids.empty?
      s1 = @boot_pids.map{|pid| " /PID #{pid} " }
      IO.popen("start /b taskkill /F #{s1}")
      @boot_pids.clear
    end
  end

  class Parent
    def initialize
      @service = Service.new
      DRb.start_service('druby://127.0.0.1:0',@service)
      @threads = []
    end
    
    def request(obj)
      @service.push obj
    end

    def spawn_children(n, cmd)
      n.times.map do |index|
        @threads << Thread.new do
          while !@abort 
            system("#{cmd} #{DRb.uri} #{index}")
          end
        end
      end
    end

    def kill_working_children
      @service.kill_working_children
    end
    
    def abort
      @abort = true
      @service.kill_boot_children
      @threads.each{ |th| th.join }
    end
  end

  class Child
    attr_accessor :index
    def initialize(index = ARGV.pop, uri = ARGV.pop)
      @index = index
      @service = DRbObject.new_with_uri(uri)
      @service.add_boot_client(Process.pid)
    end
    
    def wait_request
      req = @service.pop
      @service.add_working_client(Process.pid)
      at_exit do
        @service.remove_working_client(Process.pid)
        @service.remove_boot_client(Process.pid)
      end
      req
    end
  end
end
