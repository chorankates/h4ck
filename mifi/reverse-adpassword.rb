#/usr/bin/ruby
## reverse-adpassword.rb - Virgin Mobile Mifi login passwords are encoded, not encrypted

require 'digest/sha1'

PWTOKEN='tcqowykwoejwlgvj' # magic number from index.html inline js

## mirroring js method names
def rstr2hex(input)
  # iterate over each character
  # get it's character code (a = 97, o = 111).. so ASCII value
  # append this value shifted 4 times & 15 + the character again & 15
  ## in js: a = c.charCodeAt(i); b+=f.charAt((a>>>4)&15)+f.charAt(a&15), where f = '0123456789abcdef'
  # so .. isn't this just hexing?
  input.each_byte.map { |b| b.to_s(16) }.join
end

def rstr_sha1(input)
  # technically we can do all of the encoding with .hexdigest here, but hey, completeness
  Digest::SHA1.digest(input)
end

# TODO actually implement this, for now assuming input is ASCII anyway
def str2rstr_utf8(input)
  input
end

## main()
password = ARGV.first
if password.nil?
  p sprintf('USAGE: %s <password>', File.basename(__FILE__))
  exit 1
end

# TODO first we mimic the encoding, then we can decode
encoded = rstr2hex(rstr_sha1(str2rstr_utf8(password)))

puts sprintf('%s', encoded)
puts sprintf('%s', decoded)
