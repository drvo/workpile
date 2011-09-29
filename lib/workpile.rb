require "workpile/version"

require 'thread'

# 同じ子プロセスを複数作成
# コマンド送信
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
    
    # worker_process_num 子プロセスの数
    # cmd 子プロセスコマンド
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

    # 子プロセスにコマンド送信
    def push(s)
      @queue.push s
    end
    
    # 子プロセスからの stdout 待ち合わせ
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

    # 全ての子プロセスからの stdout 待ち合わせループ処理
    # ブロック必須。
    # ブロック引数 |index, io|
    #   index ワーカーのインデックス
    #   io 読み込み可能になったIO
    def async_select_loop(&block)
      @thread = Thread.new do
        Thread.current.abort_on_exception = true
        loop do
          self.select { |index, io|
            Thread.critical=true # なぜかとまってしまう現象が発生した。その対応を常に入れておくことにしました。
            block.call(index, io)
            Thread.critical=false # なぜかとまってしまう現象が発生した。その対応を常に入れておくことにしました。
            Thread.pass
          }
        end
      end
    end

    # 現在、コマンドを受け付けて処理実行中のワーカー一覧
    def processing_wokers
      @workers.select{|wk| wk.status == :processing }
    end
  end

  # 子プロセス１つを管理するクラス
  class Worker
    attr_accessor :read_pipe, :status, :index
  
    # index 子プロセスインデックス
    # cmd 実行コマンド
    # que 各Workerクラスで、共通で参照するコマンドキュー。
    def initialize(index, cmd, que)
      super()
      @index = index
      @queue = que
      @cmd = cmd
      @read_pipe, @write_pipe = *IO.pipe
      update_status(:initialized)
      _async_push_watch_loop
    end

    # 子プロセスへ直接コマンド送信
    def push(str)
      @popen_pipe.puts str
    end
    
    def close
      _close
    end

    # 状態を更新する
    def update_status(status)
      @status = status
    end

    # 子プロセスを開始する
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
