require 'workpile'
cl = Workpile::Child.new

puts "#{cl.index}>#{cl.wait_request.inspect}"

loop{sleep(1)}
