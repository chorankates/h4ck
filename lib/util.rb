#!/usr/bin/ruby

require 'base64'
require 'net/http'
require 'uri'

class Utility

  # TODO add a logger here

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

  def self.base64_decode(string)
    Base64.strict_decode64(string)
  end

  def self.base64_encode(string)
    Base64.strict_decode64(string)
  end

  def self.uri_encode(string)
    URI.encode(string)
  end

  def self.uri_decode(string)
    URI.decode(string)
  end

  def self.uri_form_decode(string)
    h = Hash.new

    URI.decode_www_form(string).each do |array|
      h[array.first.to_sym] = array.last
    end

    h
  end


end