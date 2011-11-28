require 'workpile'

sv = Workpile::Parent.new
sv.spawn_children(3, "ruby -I../lib child.rb 1 2")

while s = gets
  case s
  when /exit/
    sv.abort
    exit
  when /kill/
    sv.kill_working_children
  else
    sv.request s
  end
end
