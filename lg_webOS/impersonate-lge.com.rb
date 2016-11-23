#/usr/bin/env ruby
## impersonate-lge.com.rb - fake version of *.lge.com

# serving a cooked version of busybox and base-files

require 'sinatra'

port   = ENV['USER'].eql?('root') ? 80 : 8080
set :port, port
set :bind, '0.0.0.0'

set :public_folder, '_public'

@type = @real_file = @fake_file = nil

get '/fts/:file' do |file|

  target_host = request.host

  if target_host.match(/gfts/)
    @type = :ngfts
    # http://gfts.lge.com/fts/gftsFilePathDownload.lge?key=777863&hash=6Vsai7Ky71UPgetV&mtime=1479098823000
    # this is the opkg update path

    #redirect '/base-files/base-files.ipk'

    # unfortunately, we need to set these headers:
    # Server: Apache
    # Content-Disposition: attachment; filename="16881482.ipk"
    # Content-Transfer-Encoding: binary;
    # Content-Type: application/octet-stream;charset=UTF-8

    # and currently, we send:
    # Content-Type: application/vnd.shana.informed.package
    # and the other fields are empty

    headers(
      'Content-Disposition'       => 'attachment; filename="base-files.ipk"',
      'Content-Transfer-Encoding' => 'binary',
      'Content-Type'              => 'application/octet-stream;charset=UTF-8',
      'Server'                    => 'Apache',
    )

    send_file File.join(settings.public_folder, '/base-files/base-files.ipk')

  elsif target_host.match(/ngfts/)
    @type = :ngfts
    biz_code = '' # TODO fill this in
    if biz_code.eql?('PREMIUMS')
      # TODO /fts/gftsDownload.lge?biz_code=PREMIUM&func_code=RECOMM_PROMOTION_IMAGE&file_path=/todayrecomm/template/promotion/w1_8.png
    elsif biz_code.eql?('META_IMG')
      # TODO /fts/gftsDownload.lge?biz_code=META_IMG&func_code=CPLOGO&file_path=/appstore/app/icon/20161017/16837781.png
    elsif biz_code.eql?('IBS')
      # TODO /fts/gftsDownload.lge?biz_code=IBS&func_code=TMS_CHANNEL_IMG_US&file_path=/ibs/tms/channel_img_us/201412040000_9.zip
    elsif biz_code.eql?('APP_STORE')
      # TODO /fts/gftsDownload.lge?biz_code=APP_STORE&func_code=APP_PREVIEW&file_path=/appstore/app/preview/20160221/3.jpg
    elsif biz_code.eql?('MAS')
      # TODO /fts/gftsDownload.lge?biz_code=MAS&func_code=META_THUMBNAIL&file_path=%2Fmas%2Ftms%2Fprogram%2Fp185554_b_ap.jpg
    end
    redirect '/ngfts/faked-ngfts.zip'
  elsif target_host.match(/aic/)
    @type = :aic
    @real_file = '/aic/faked-aic.zip'
    @fake_file = '16881482.ipk'
    redirect real_file
  else
    # failover
    'your princess is in another castle'
  end
end

after do

  t = Time.now + (8 * 60 * 60)
  timestamp = t.strftime('%a, %d %b %Y %H:%m:%S GMT')

  if @type.eql?(:aic)
    response['Server'] = 'Apache'
    response['Content-Disposition'] = sprintf('attachment; filename="%s"', @fake_file)
    response['Content-Transfer-Encoding'] = 'binary'
    response['Content-Type'] = 'image/jpeg;charset=UTF-8'
    response['Connection'] = 'keep-alive'
    response['Content-Length'] = File.read(@real_file).size
    response['Last-Modified'] = timestamp
    response['Date'] = timestamp
  end

  @type = @real_file = @fake_file = nil
end