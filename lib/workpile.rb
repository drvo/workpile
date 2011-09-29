require "workpile/version"

require 'thread'

# �����q�v���Z�X�𕡐��쐬
# �R�}���h���M
#
# useage: 
# wpcl = Workpile.client(3, "ruby server.rb")
#
# wpcl.async_select_loop do |worker, io|
#   puts "#{worker.index} > #{io.gets}"
# end
module Workpile
  def self.client(worker_process_num, cmd)
    Client.new(worker_process_num, cmd)
  end

  class Client
    attr_accessor :workers
    
    # worker_process_num �q�v���Z�X�̐�
    # cmd �q�v���Z�X�R�}���h
    def initialize(worker_process_num, cmd)
      @queue = Queue.new
      @workers = worker_process_num.times.map { |i| Worker.new(i, cmd, @queue) }
      Thread.new do
        Thread.current.abort_on_exception = true
        @workers.each { |wk|
          wk.start
        }
      end
    end
    
    def close
      @workers.each{|wk| wk.close}
    end

    # �q�v���Z�X�ɃR�}���h���M
    def push(s)
      @queue.push s
    end
    
    # �q�v���Z�X����� stdout �҂����킹
    def select(&block)
      current_io = @workers.map{|cn| cn.read_pipe }
      r = IO.select(current_io)
      Thread.pass
      ret = nil
      if r
        ret = r[0].map do |io|
          {:worker => @workers.find{|f| f.read_pipe == io }, :io=>io }
        end
      end
      if ret and block
        ret.each{ |ret_one| block.call(ret_one[:worker].index, ret_one[:io]) }
        Thread.pass
      end
      ret
    end

    # �S�Ă̎q�v���Z�X����� stdout �҂����킹���[�v����
    # �u���b�N�K�{�B
    # �u���b�N���� |index, io|
    #   index ���[�J�[�̃C���f�b�N�X
    #   io �ǂݍ��݉\�ɂȂ���IO
    def async_select_loop(&block)
      @thread = Thread.new do
        Thread.current.abort_on_exception = true
        loop do
          self.select { |index, io|
            Thread.critical=true # �Ȃ����Ƃ܂��Ă��܂����ۂ����������B���̑Ή�����ɓ���Ă������Ƃɂ��܂����B
            block.call(index, io)
            Thread.critical=false # �Ȃ����Ƃ܂��Ă��܂����ۂ����������B���̑Ή�����ɓ���Ă������Ƃɂ��܂����B
            Thread.pass
          }
        end
      end
    end

    # ���݁A�R�}���h���󂯕t���ď������s���̃��[�J�[�ꗗ
    def processing_wokers
      @workers.select{|wk| wk.status == :processing }
    end
  end

  # �q�v���Z�X�P���Ǘ�����N���X
  class Worker
    attr_accessor :read_pipe, :status, :index
  
    # index �q�v���Z�X�C���f�b�N�X
    # cmd ���s�R�}���h
    # que �eWorker�N���X�ŁA���ʂŎQ�Ƃ���R�}���h�L���[�B
    def initialize(index, cmd, que)
      super()
      @index = index
      @queue = que
      @cmd = cmd
      @read_pipe, @write_pipe = *IO.pipe
      update_status(:initialized)
      _async_push_watch_loop
    end

    # �q�v���Z�X�֒��ڃR�}���h���M
    def push(str)
      @popen_pipe.puts str
    end
    
    def close
      _close
    end

    # ��Ԃ��X�V����
    def update_status(status)
      @status = status
    end

    # �q�v���Z�X���J�n����
    def start
      update_status(:started)
      Thread.new do
        Thread.current.abort_on_exception = true
        loop do
          Thread.pass
          _boot
          _io_loop rescue EOFError
          _close
        end
      end
    end

private
    def _boot
      update_status(:booting)
      @popen_pipe = IO.popen(@cmd, "r+")
    end

    def _analize_workpile_cmd(s)
      if s =~ /^workpilecmd :(.*)/
        case $1
        when "booting"
          update_status(:boot_wait)
        when "ready"
          update_status(:ready)
        end
      end
    end

    def _io_loop
      while s = @popen_pipe.readpartial(65535)
        _analize_workpile_cmd(s)
        @write_pipe.write s
        Thread.pass
      end
    end
    
    def _close
      @popen_pipe.close
      @popen_pipe = nil
    end
    
    def _async_push_watch_loop
      Thread.new do
        Thread.current.abort_on_exception = true
        loop do
          dt = @queue.pop
          if @popen_pipe
            @popen_pipe.puts dt
            Thread.pass
            update_status(:processing)
          end
        end
      end
    end
  end
end
