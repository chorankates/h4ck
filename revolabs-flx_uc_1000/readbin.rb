#!/usr/bin/env ruby
## readbin.rb - given offsets, read binary files out of a packed file

file   = ARGV.pop  || 'FLX-UC-1500-2-6-0-294.bundle'
outdir = ARGV.last || sprintf('rb-out_%s.%s', file, Time.now.to_i)
files  = Hash.new

offset_map = {
  'FLX-UC-1500-2-6-0-294.bundle' => [ 0, 138364, 266272, 283460, 1708064, 19642065, File.size('FLX-UC-1500-2-6-0-294.bundle') ]
}

unless File.file?(file)
  puts sprintf('unable to read[%s]', file)
  exit 1
end

unless File.directory?(outdir)
  puts sprintf('creating[%s]', outdir)
  Dir.mkdir(outdir)
end

#offsets = [ 0, 138364, 266272, 283460, 1708064, 19642065, File.size(file) ]

offsets = offset_map[file]

# read in the file in segments, stuff in a hash
open(file, 'rb') do |f|
  offsets.each_with_index do |offset, i|
   forward  = offsets[i+1]
   backward = offsets[i-1]

   break if forward.nil? # we're at the end of the file

   length = (offset - forward).abs

   puts sprintf('offset[%s] at[%s] reading[%s]..', i, offsets[i], length)

   f.seek(offset)
   s = f.read(length)

   files[offset] = {
     :i        => i,
     :contents => s,
   }

   puts sprintf('  got[%s]', s.size)

  end
end

# write out each of the files
files.each_pair do |offset, hash|

  hex = sprintf('0x%s', sprintf('%x', offset).upcase)
  name = sprintf('%s/%s.%s.out', outdir, hash[:i], hex)

  puts sprintf('writing[%s]', name)

  open(name, 'wb') do |f|
    f.write(hash[:contents])
  end

  puts sprintf('  size[%s]', File.size?(name))

end

