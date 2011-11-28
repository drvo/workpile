require 'rubygems'
require 'workpile'

sv = Workpile::Parent.new
sv.spawn_children(3, "ruby child.rb 1 2")

while s = gets
  if s =~ /exit/
    p sv
    sv.kill_working_children
  else
    sv.request s
  end
end
