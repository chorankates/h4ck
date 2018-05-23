#!/usr/bin/env ruby
## soluapp-enumerator.rb - enumerates soluapp.pub IDs for users and stories

require 'digest'
require 'net/http'
require 'uri'

module Soluapp

  URL_TEMPLATES = {
    :one => {
      :legacy_chapter => 'http://soluapp.pub/legacy-chapter.php?id=%i',
      :story_slide    => 'http://soluapp.pub/story_slide.php?userid=%i&key=0&ty=',
    },
    :two => {
      :last_story   => 'http://soluapp.pub/legacy/last_story1.php?userid=%i&id=%i&img=bg_image7.png&key=0&ty=&chapkey=0',
      :write_legacy => 'http://soluapp.pub/legacy/write_legacy.php?id=%i&img=&key=&chapkey=&ty=&user=%i',
    },
    :buckle_my_shoe => {},
  }

  class Utility

    def self.get_url_one(type, id)
      sprintf(URL_TEMPLATES[:one][type], id)
    end

    def self.get_url_two(type, id1, id2)
      sprintf(URL_TEMPLATES[:two][type], id1, id2)
    end

    def self.get_url(url)
      uri      = URI.parse(url)
      http     = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      request  = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      if response.code.eql?('301')
        return self.get_url(response.header['location'])
      end

      response
    end

  end

  class Response

    attr_reader :url, :response, :hash, :size, :success

    def initialize(url, response)
      @url      = url
      @response = response
      @success  = ! response.code.match(/4.*/)

      @hash     = Digest::MD5.hexdigest(response.body)
      @size     = response.body.length
    end
  end

  class Application
    attr_reader :type, :ceiling, :floor, :responses

    def initialize(type, ceiling = 10_000, floor = 0)
      @type      = type.to_sym
      @ceiling   = ceiling
      @floor     = floor
      @responses = Array.new

      raise StandardError.new(sprintf('invalid type[%s] specified', type)) unless URL_TEMPLATES[:one].has_key?(type) or URL_TEMPLATES[:two].has_key?(type)
    end

    def inspect
      candidate = {
        :type    => @type,
        :ceiling => @ceiling,
        :floor   => @floor,
      }

      candidate.delete(:floor) if @floor.eql?(0)
      candidate
    end

    def to_s
      self.inspect.to_s
    end

    def request!

      return request_url_one if URL_TEMPLATES[:one].has_key?(@type)
      return request_url_two if URL_TEMPLATES[:two].has_key?(@type)

    end

    def request_url_one

      @floor.upto(@ceiling) do |i|
        url         = Soluapp::Utility.get_url_one(@type, i)
        response    = Soluapp::Utility.get_url(url)
        @responses << Soluapp::Response.new(url, response)
      end

    end

    def request_url_two

      @floor.upto(@ceiling) do |i|
        @floor.upto(@ceiling) do |j|
          url         = Soluapp::Utility.get_url_two(@type, i, j)
          response    = Soluapp::Utility.get_url(url)
          @responses << Soluapp::Response.new(url, response)
        end
      end

    end

    def summarize
      successes = @responses.select { |r| r.success.eql?(true) }
      failures  = @responses - successes

      puts sprintf('total responses[%i]', @responses.size)
      puts sprintf('  successful responses[%i]', successes.size)
      puts sprintf('  failed responses    [%i]', failures.size)

      sizes = Hash.new(0)
      successes.each do |s|
        sizes[s.size] += 1
      end

      puts sprintf('size distribution[%s]', sizes)

      md5s = Hash.new('')
      successes.each do |s|
        md5s[s.hash] += 1
      end

      puts sprintf('hash distribution[%s]', md5s)
    end

  end

end

ceiling = 10
floor   = 0

[
  :legacy_chapter,
  :story_slide,
  :last_story,
  :write_legacy,
].each do |type|
  app = Soluapp::Application.new(type, ceiling, floor)

  app.request!

  app.summarize

end