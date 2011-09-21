require 'workpile'
require 'timeout'

$stdout.sync=true

puts "workpilecmd :booting"

puts "workpile server sleeping"
begin
  timeout(5) do
    loop do
      puts "booting received [#{gets.chomp}]"
    end
  end
rescue Timeout::Error
end

puts "workpile server booted"

puts "workpilecmd :ready"

puts $stdin.gets

puts "workpile server processing 5sec"

begin
  timeout(5) do
    loop do
      puts "processing received [#{gets.chomp}]"
    end
  end
rescue Timeout::Error
end
