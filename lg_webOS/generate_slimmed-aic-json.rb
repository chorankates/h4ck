#!/usr/bin/env ruby
## generate_slimmed-aic-json.rb -- generates a zip file suitable for faking the tv schedule

require 'json'

target_dir = sprintf('%s/_public/aic', File.expand_path(File.dirname(__FILE__)))
source_dir = sprintf('%s/_source/slimmed', target_dir)
target_zip = sprintf('%s/faked-aic.zip', target_dir)

synchro          = Time.now
datestamp        = synchro.strftime('%Y-%m-%d-05:00')

schedule_filename = sprintf('%s/schedule.json', source_dir)

start_time_commas = synchro.strftime('%Y,%m,%d,%h,00,00') # as close to real as possible, but faking the last bit
start_time_ticks  = synchro.to_i

end_time_ticks  = start_time_ticks + (30 * 60) # adding 30 minuted
end_time_commas = Time.at(end_time_ticks).strftime('%Y,%m,%d,%h,00,00')

uniq_id      = sprintf('0229597%s', 10001 + rand(1000))
content_id   = sprintf('EP%s', uniq_id)
program_id   = sprintf('SH%s', uniq_id)
channel_code = '100006'

schedule_id  = sprintf('%s/%s/%s', channel_code, content_id, datestamp) # 100006/EP022959710001/2016-11-11-05:00

h4ck_text = 'h4ck the planet'

schedule = {
    'updateType'   => 'full',
    'schCount'     => '1',
    'scheduleList' => [
    {
      'dbAction'              => 'I',
      'schdId'                => schedule_id,
      'contentId'             => content_id, # this needs to match above and in program.json, but also needs to be unique
      'seqNo'                 => '0',
      'chanCode'              => channel_code,
      'strtTime'              => start_time_commas,
      'strtTimeLong'          => start_time_ticks,
      'endTime'               => end_time_commas,
      'endTimeLong'           => end_time_ticks,
      'schdSummary'           => h4ck_text,
      'timeType'              => '', # this was blank in the source too
      'schdPgmTtl'            => h4ck_text,
      'schdSubTtl'            => h4ck_text,
      'rebrdcstFlag'          => 'Y',
      'capFlag'               => '',
      'liveFlag'              => '',
      'dataBrdcstFlag'        => '',
      'scExplnBrdcstFlag'     => '',
      'scQualityGbn'          => '',
      'signBrdcstFlag'        => '',
      'voiceMultiBrdcstCount' => '',
      'threeDFlag'            => '',
      'schdAdultClassCode'    => '-1',
      'schdAgeGrdCode'        => 'TVG',
      'pgmGrId'               => program_id,
      'genreCode'             => '61',
      'realEpsdNo'            => '0'
    },
  ]
}

puts sprintf('outputting schedule to[%s]', schedule_filename)

File.open(schedule_filename, 'w') do |f|
  f.puts schedule.to_json
end


## now build program.json

connector_id = '1010999'
serial_id    = '184168'
season_id    = '7894663'

aic_h4ck_image = 'http://aic-gfts.lge.com/aic/hacktheplanet.jpg'

program_filename = sprintf('%s/program.json', source_dir)

program = {
    'updateType'   => 'full',
    'contentSetId' => 'com.lge.crawler.xml.tms.TmsEpgCrawler',
    'pgmCount'     => '1',
    'programList'  => [
    {
      'dbAction'      => 'I',
      'contentId'     => content_id,
      'seqNo'         => '0',
      'pgmGrId'       => program_id,
      'connectorId'   => connector_id,
      'serId'         => serial_id,
      'serNo'         => '',
      'seasonId'      => season_id,
      'seasonNo'      => '2',
      'pgmType'       => 'Series',
      'realEpsdNo'    => '13',
      'summary'       => h4ck_text,
      'pgmImgUrlName' => aic_h4ck_image,
      'orgGenreType'  => '',
      'orgGenreCode'  => '5',
      'oGenreCode'    => '2',
      'oGenreType'    => '',
      'subGenreType'  => '',
      'subGenreCode'  => '',
      'makeCom'       => '',
      'makeCntry'     => '',
      'makeYear'      => '1988-02-07',
      'usrPplrSt'     => '',
      'pplrSt'        => '',
      'audLang'       => 'en',
      'dataLang'      => 'ENG',
      'audQlty'       => '',
      'genreImgUrl'   => aic_h4ck_image,
      'vodFlag'       => 'N',
      'pgmImgSize'    => 'V480X720',
      'genreImgSize'  => 'V480X720',
      'lgGenreCode2'  => '14',
      'lgGenreName2'  => 'Crime',
      'programLock'   => '',
      'castingFlag'   => 'Y'
    },
  ]
}


puts sprintf('outputting program to[%s]', program_filename)

File.open(program_filename, 'w') do |f|
  f.puts program.to_json
end

puts sprintf('creating[%s]', target_zip)
`cd #{source_dir}; zip #{target_zip} #{File.basename(program_filename)} #{File.basename(schedule_filename)}; ls -l #{target_zip}`
