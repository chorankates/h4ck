#/usr/bin/env ruby
## impersonate-lge.com.rb - fake version of *.lge.com

require 'base64'
require 'sinatra'

port   = ENV['USER'].eql?('root') ? 80 : 8080
set :port, port
set :bind, '0.0.0.0'

set :public_folder, '_public'

@type = @real_file = @fake_file = nil

get '/fts/:file' do |file|

  t = Time.now + (8 * 60 * 60)
  timestamp = t.strftime('%a, %d %b %Y %H:%m:%S GMT')

  target_host = request.host

  if target_host.match(/gfts/)
    @type = :gfts
    ## app store downloads
    # http://gfts.lge.com/fts/gftsFilePathDownload.lge?key=777863&hash=6Vsai7Ky71UPgetV&mtime=1479098823000


    key   = params['key']   # 777863
    hash  = params['hash']  # 6Vsai7Ky71UPgetV
    mtime = params['mtime'] # 1479098823000

    fake_ipk_name = '16881482.ipk'
    real_ipk_file = File.join(settings.public_folder, '/gfts/base-files.ipk')

    headers(
      'Content-Disposition'       => sprintf('attachment; filename="%s"', fake_ipk_name),
      'Content-Transfer-Encoding' => 'binary',
      'Content-Type'              => 'application/octet-stream;charset=UTF-8',
      'Server'                    => 'Apache',
    )

    send_file real_ipk_file

  elsif target_host.match(/ngfts/)
    ## channel searching -- images / thumbnails
    # samples in line
    @type = :ngfts

    biz_code  = params['biz_code']
    func_code = params['func_code']
    file_path = params['file_path']

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

    # failover
    redirect '/ngfts/faked-ngfts.zip'

  elsif target_host.match(/aic/)
    ## channel searching - listing JSON
    # http://aic-gfts.lge.com/fts/gftsDownload.lge?biz_code=IBS&func_code=ONLINE_EPG_FILE&file_path=/ibs/online/epg_file/20161116/f_1479280636996tmsepgcrawler_merged000004417_201611160600_06_20161116070000.zip
    @type = :aic

    fake_file = 'TODO' # TODO not sure what this is supposed to be
    real_file = File.join(settings.public_folder, '/aic/faked-aic.zip')

    if @type.eql?(:aic)
      headers(
          'Server'                    => 'Apache',
          'Content-Disposition'       => sprintf('attachment; filename="%s"', fake_file),
          'Content-Transfer-Encoding' => 'binary',
          'Content-Type'              => 'image/jpeg;charset=UTF-8',
          'Connection'                => 'keep-alive',
          'Content-Length'            => File.read(real_file).size,
          'Last-Modified'             => timestamp,
          'Date'                      => timestamp,
      )
    end

    send_file real_file

  else
    # failover
    'your princess is in another castle - lge'
  end
end

post '/CheckSWAutoUpdate.laf' do
  t = Time.now + (8 * 60 * 60)
  timestamp = t.strftime('%a, %d %b %Y %H:%m:%S GMT')

  req_id = '00000000008613244660'

  image_url  = 'http://snu.lge.com/fizbuzz'
  image_size = '400'
  image_name = 'fizzbuzz'

  update_major_ver = '04'
  update_minor_ver = '30.50' # right now, anything more than 30.40

  force_flag = 'Y'
  cdn_url    = 'http://snu.lge.com/fizzbuzz'
  contents   = ''

  string = "<RESPONSE>
<RESULT_CD>900</RESULT_CD>
<MSG>Success</MSG>
<REQ_ID>#{req_id}</REQ_ID>
<IMAGE_URL>#{image_url}</IMAGE_URL>
<IMAGE_SIZE>#{image_size}</IMAGE_SIZE>
<IMAGE_NAME>#{image_name}</IMAGE_NAME>
<UPDATE_MAJOR_VER>#{update_major_ver}</UPDATE_MAJOR_VER>
<UPDATE_MINOR_VER>#{update_minor_ver}</UPDATE_MINOR_VER>
<FORCE_FLAG>#{force_flag}</FORCE_FLAG>
<KE></KE>
<GMT>#{timestamp}</GMT>
<ECO_INFO>01</ECO_INFO>
<CDN_URL>#{cdn_url}</CDN_URL>
<CONTENTS>#{contents}</CONTENTS>
</RESPONSE>"

  payload = Base64.strict_encode64(string)

  headers(
    'Date'           => timestamp,
    'Pragma'         => 'no-cache',
    'Expires'        => '-1',
    'Content-Type'   => 'application/octet-stream;charset=UTF-8',
    'Content-Length' => payload.size,
  )

  payload
end

after do
  # noop for now
end