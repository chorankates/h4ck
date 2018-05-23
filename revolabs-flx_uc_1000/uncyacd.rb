#!/usr/bin/env ruby
## uncyacd.rb -- reconstituting PSoC boot files from their proprietary format

# .cyacd file format:
#                 [4-byte SiliconID][1-byte SiliconRev][checksum type]
# The data records have the format:
#                               [1-byte ArrayID][2-byte RowNumber][2-byte DataLength][N-byte Data][1byte Checksum]
# The Checksum is computed by summing all bytes (excluding the checksum itself) and then taking the 2's complement.

filename = ARGV.first || sprintf('%s/git/rouster/USB_Digital_Audio1500_bb.cyacd', ENV['HOME']) if filename.nil?
filename = sprintf('%s/git/h4ck/revolabs-flx_uc_1000/test.cyacd', ENV['HOME'])

unless File.file?(filename)
  puts sprintf('USAGE: %s <file.cyacd>', File.basename(__FILE__))
  exit 0
end

File.open(filename, 'rb') do |f|

  to_read = 1
  array_id = f.read(to_read)

  to_read = 2
  row_number = f.read(to_read)

  to_read = 2
  data_length = f.read(to_read)

  to_read = data_length
  data = f.read(to_read) # TODO not sure that this will actually be an integer

  to_read = 1
  checksum = f.read(to_read)

  p 'DBGZ' if nil?
end

# current_bucket = 0
# bucket_size    = 10
#
# File.open(filename, 'rb') do |f|
#   p 'DBGZ' if nil?
#   f.seek(current_bucket * bucket_size)
#   s = f.read(bucket_size)
#   current_bucket += 1
#   p 'DBGZ' if nil?
# end

contents = File.read(filename)

contents.split("\n").each do |line|
  # this should show us how to actually do this: https://github.com/gv1/hex2cyacd/blob/master/ihex2cyacd.pl
  split = line.split(':')
  label = split.first.chomp
  split[1..split.size].each do |data|
    p 'DBGZ' if nil?
  end

end

