#!/usr/bin/env ruby
## json-list.rb - call /json/list?t=1477610858021..0

require_relative '../lib/util'
require 'json'

u = Utility.new

h = ARGV.first || '10.10.10.1'
p = 9998

start = 1477610858021
start = 1477610600000
SPACER = 1_000

start.downto(0).each do |i|

  # TODO figure out a good way to abstract this and put in utility class
  if (i % SPACER).eql?(0)
    puts sprintf('  [%s/%s] [%.2f%%]', i, start, (start.to_f / i.to_f) * 100)
  end

  url  = sprintf('http://%s:%s/json/list?t=%s', h, p, i)
  data = nil

  begin
    response = Utility.get_url(url)
    data = JSON.parse(response.body)

    unless data.empty?
      puts sprintf('INFO: [%s] gave non-empty response[%s]', i, data)
      File.open('found.txt', 'w') { |f| f.print sprintf('i[%s] data[%s]', i, data) }
    end

  rescue => e
    puts sprintf('ERROR: unable to parse[%s]: [%s]', response.body, e.message)
  end

end