#!/usr/bin/env ruby
## generate_contacts.csv

# duplicate records
max      = 10
filename = 'contacts-duplicates.csv'
headers  = 'name,mobile,work,home,default,speed,key'
record   = 'foo,,1234567,,work,-1,656877352' # unclear what the trailing digit is supposed to indicate, except that it is usually +1 from the last one created -- should we do that too?

File.open(filename, 'w') do |f|
  f.write(headers)
  0.upto(max).each do |_i|
    f.write(sprintf('%s%s', record, "\n"))
  end
end

puts sprintf('created: %s', filename)

# a large number of records
max      = 100_000
filename = 'contacts-huge.csv'
record   = '%s,,%s,,work,-1,%s%s'

File.open(filename, 'w') do |f|

  f.write(headers)
  0.upto(max) do |i|
    f.write(sprintf(record, sprintf('foo%s', i), rand(max), rand(max) + 1, "\n"))
  end
end

puts sprintf('created: %s', filename)
