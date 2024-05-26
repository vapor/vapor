#!/usr/bin/ruby

puts "Starting Swift-Periphery dead code analyzer"

result = `periphery scan --targets Vapor --retain-public --clean-build`

result_stripped_of_absolute_path_prefix = result.gsub(Dir.pwd, '')
filtered_out_result = result_stripped_of_absolute_path_prefix.split("\n").filter { |line| /:\d+:\d+:/.match?(line) }
sorted_result = filtered_out_result.sort
result_with_removed_code_line_number = sorted_result.map {|l| l.sub(/:\d+:\d+:/, '') }
output = result_with_removed_code_line_number.join("\n") + "\n"

File.write('periphery.out', output)

unused_code_count = result_with_removed_code_line_number.size
puts "Done with #{unused_code_count} matches. Check results in periphery.out"
