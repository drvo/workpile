require 'workpile'
Thread.abort_on_exception

wpcl = Workpile.client(3, "ruby server.rb")

wpcl.async_select_loop do |index, io|
  puts "#{index} > #{io.gets}"
end

while s = gets
  if s =~ /kick/
    p "kicked"
    wpcl.processing_wokers.each { |wk|
      wk.push "close window"
    }
  else
    wpcl.push s
  end
end
