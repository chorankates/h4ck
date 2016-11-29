# LG webOS

- [TV](#TV)
- [digging](#digging)
  - [nmap](#nmap)
  - [sniffing](#sniffing)
    - [on boot](#on-boot)
    - [channel search](#channel-search)
    - [application marketplace](#application-marketplace)
- [impersonating](#impersonating)
  - [channel guide](#channel-guide)
  - [application update](#application-update)

## TV
name|value
----|-----
model|43UH6100
product|`3.0`
firmware|`4.30.40`
features|app marketplace, live TV listings 
vulnerabilities|all phone-home calls are done over `HTTP`

the `43UH6100` is a 'smart' TV, running LG's [webOS](https://en.wikipedia.org/wiki/WebOS)
since it is a fair assumption it is running [OpenWrt](https://en.wikipedia.org/wiki/OpenWrt) underneath, the original goal
was rooting the device, but initial investigations showed some other interesting vectors

## digging

### nmap

from `nmap -PN -sV <device>`, we get:

```
PORT     STATE SERVICE  VERSION
1175/tcp open  upnp
3000/tcp open  http     LG smart TV http service
3001/tcp open  ssl/http LG smart TV http service
9998/tcp open  http     Google Chromecast httpd
```

aside from the obvious flag running of both HTTP and HTTPS versions of (likely) the same service,
interested to see that the Chromecast plugged in to the TV is also being exposed on the same IP as the TV

since there is an [LG smart TV](http://www.lg.com/us/experience-tvs/smart-tv) app available for [Android](https://play.google.com/store/apps/details?id=com.lge.tv.remoteapps&hl=en)/[iOS](https://itunes.apple.com/us/app/lg-tv-remote/id509979485), assuming that there is an API of some sort running on `3000` or `3001`, so:

```
$ curl http://<device>:3000
Hello world
```

we see the same response on `3001`, but have to use `-k` as the device uses a self-signed certificate

so, something is there, we just don't know how to talk to it yet

### sniffing

switching tactics and connected the TV to a wireless network that has a tap, and we start to see some interesting things:

#### on boot
  
every time the TV starts up, within 30 seconds, it calls home:

```
POST /CheckSWAutoUpdate.laf HTTP/1.1
Accept: */*
User-Agent: User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)
Host: snu.lge.com:80
Connection: Keep-Alive
Content-type: application/x-www-form-urlencoded
Content-Length: 572

PFJFUVVFU1Q+CjxQUk9EVUNUX05NPndlYk9TVFYgMy4wPC9QUk9EVUNUX05NPgo8TU9ERUxfTk0+SEVfRFRWX1cxNlBfQUZBREFUQUE8L01PREVMX05NPgo8U1dfVFlQRT5GSVJNV0FSRTwvU1dfVFlQRT4KPE1BSk9SX1ZFUj4wNDwvTUFKT1JfVkVSPgo8TUlOT1JfVkVSPjMwLjQwPC9NSU5PUl9WRVI+CjxDT1VOVFJZPlVTMjwvQ09VTlRSWT4KPENPVU5UUllfR1JPVVA+VVM8L0NPVU5UUllfR1JPVVA+CjxERVZJQ0VfSUQ+MTQ6Yzk6MTM6MGU6ZWU6YzI8L0RFVklDRV9JRD4KPEFVVEhfRkxBRz5OPC9BVVRIX0ZMQUc+CjxJR05PUkVfRElTQUJMRT5OPC9JR05PUkVfRElTQUJMRT4KPEVDT19JTkZPPjAxPC9FQ09fSU5GTz4KPENPTkZJR19LRVk+MDA8L0NPTkZJR19LRVk+CjxMQU5HVUFHRV9DT0RFPmVuLVVTPC9MQU5HVUFHRV9DT0RFPjwvUkVRVUVTVD4K
```

```
HTTP/1.1 200 OK
Date: Wed, 16 Nov 2016 08:23:56 GMT
Content-length: 508
Content-type: application/octet-stream;charset=UTF-8
Pragma: no-cache;
Expires: -1;
Content-Transfer-Encoding: binary;

PFJFU1BPTlNFPjxSRVNVTFRfQ0Q+OTAwPC9SRVNVTFRfQ0Q+PE1TRz5TdWNjZXNzPC9NU0c+PFJFUV9JRD4wMDAwMDAwMDAwODcyOTE5MDEzNjwvUkVRX0lEPjxJTUFHRV9VUkw+PC9JTUFHRV9VUkw+PElNQUdFX1NJWkU+PC9JTUFHRV9TSVpFPjxJTUFHRV9OQU1FPjwvSU1BR0VfTkFNRT48VVBEQVRFX01BSk9SX1ZFUj48L1VQREFURV9NQUpPUl9WRVI+PFVQREFURV9NSU5PUl9WRVI+PC9VUERBVEVfTUlOT1JfVkVSPjxGT1JDRV9GTEFHPjwvRk9SQ0VfRkxBRz48S0U+PC9LRT48R01UPjE2IE5vdiAyMDE2IDA4OjIzOjU2IEdNVDwvR01UPjxFQ09fSU5GTz4wMTwvRUNPX0lORk8+PENETl9VUkw+PC9DRE5fVVJMPjxDT05URU5UUz48L0NPTlRFTlRTPjwvUkVTUE9OU0U+
```
  
that looks a lot like base64 encoded data, and when decoded, yields

request:
```xml
<REQUEST>
  <PRODUCT_NM>webOSTV 3.0</PRODUCT_NM>
  <MODEL_NM>HE_DTV_W16P_AFADATAA</MODEL_NM>
  <SW_TYPE>FIRMWARE</SW_TYPE>
  <MAJOR_VER>04</MAJOR_VER>
  <MINOR_VER>30.40</MINOR_VER>
  <COUNTRY>US2</COUNTRY>
  <COUNTRY_GROUP>US</COUNTRY_GROUP>
  <DEVICE_ID>de:ad:be:ef:ca:fe</DEVICE_ID>
  <AUTH_FLAG>N</AUTH_FLAG>
  <IGNORE_DISABLE>N</IGNORE_DISABLE>
  <ECO_INFO>01</ECO_INFO>
  <CONFIG_KEY>00</CONFIG_KEY>
  <LANGUAGE_CODE>en-US</LANGUAGE_CODE>
</REQUEST>
```

pretty standard, but the `auth_flag`, `ignore_disable` and `config_key` values are potentially interesting

response:
```xml
<RESPONSE>
  <RESULT_CD>900</RESULT_CD>
  <MSG>Success</MSG>
  <REQ_ID>00000000000000000001</REQ_ID>
  <IMAGE_URL></IMAGE_URL>
  <IMAGE_SIZE></IMAGE_SIZE>
  <IMAGE_NAME></IMAGE_NAME>
  <UPDATE_MAJOR_VER></UPDATE_MAJOR_VER>
  <UPDATE_MINOR_VER></UPDATE_MINOR_VER>
  <FORCE_FLAG></FORCE_FLAG>
  <KE></KE>
  <GMT>16 Nov 2016 08:23:56 GMT</GMT>
  <ECO_INFO>01</ECO_INFO>
  <CDN_URL></CDN_URL>
  <CONTENTS></CONTENTS>
</RESPONSE>
```

much more interesting than the request:

key                |assumption
-------------------|-----------
`IMAGE_URL`        | the URL of a firmware update 
`IMAGE_SIZE`       | the size of the firmware update - are they doing this instead of checksum?
`IMAGE_NAME`       | the name of the firmware update - not sure why this is necessary
`UPDATE_MAJOR_VER` | the major version of the firmware update
`UPDATE_MINOR_VER` | the minor version of the firmware update
`FORCE_FLAG`       | whether or not to force the update - unclear if true|false or 1|0
`CDN_URL`          | URL that the firmware update is available at
`CONTENTS`         | none


half an hour of playing around with both the input and output here didn't yield any immediate results, but there is definite potential

to speed this along, observe a session where the TV updated its firmware from the manufacturer 

#### channel search

when configuring the cable connections, the TV makes a number of calls:

request:
```
GET /fts/gftsDownload.lge?biz_code=IBS&func_code=ONLINE_EPG_FILE&file_path=/ibs/online/epg_file/20161116/f_1479280636996tmsepgcrawler_merged000004417_201611160600_06_20161116070000.zip HTTP/1.1
Host: aic-ngfts.lge.com
Accept: */*
```

response:
```
HTTP/1.1 200 OK
Server: Apache
Content-Disposition: attachment; filename="f_1479280636996tmsepgcrawler_merged000004417_201611160600_06_20161116070000.zip"
Content-Transfer-Encoding: binary;
Last-Modified: Wed, 16 Nov 2016 07:25:17 GMT
Content-Length: 135700
Content-Type: application/octet-stream;charset=UTF-8
Date: Wed, 16 Nov 2016 08:24:01 GMT
Connection: keep-alive

```

parameters in request:

parameter   |assumption
------------|-----------
`biz_code`  | none
`func_code` | none
`file_path` | none

looking at the file path, if not in a chroot'd environment, potential for ~LFI - attempts thus far have shown nothing but `404`

looking at the file itself:

```
$ curl -o foo "http://aic-ngfts.lge.com/fts/path"
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  132k  100  132k    0     0   230k      0 --:--:-- --:--:-- --:--:--  230k
$ file foo
foo: Zip archive data, at least v2.0 to extract
$ unzip foo
Archive:  foo
  inflating: schedule.json
  inflating: program.json
```

##### `schedule.json`

sample entry:

```json
{
  "dbAction": "I",
  "schdId": "100006/EP010865380045/2016-11-11-10:00",
  "contentId": "EP010865380045",
  "seqNo": "0",
  "chanCode": "100006",
  "strtTime": "2016,11,11,10,00,00",
  "strtTimeLong": 1478858400,
  "endTime": "2016,11,11,12,00,00",
  "endTimeLong": 1478865600,
  "schdSummary": "",
  "timeType": "",
  "schdPgmTtl": "Late Night Gifts",
  "schdSubTtl": "Lisa Rinna",
  "rebrdcstFlag": "Y",
  "capFlag": "",
  "liveFlag": "",
  "dataBrdcstFlag": "",
  "scExplnBrdcstFlag": "",
  "scQualityGbn": "",
  "signBrdcstFlag": "",
  "voiceMultiBrdcstCount": "",
  "threeDFlag": "",
  "schdAdultClassCode": "-1",
  "schdAgeGrdCode": "TVG",
  "pgmGrId": "SH010865380000",
  "genreCode": "61",
  "realEpsdNo": "0"
}
```


##### `program.json`

```json
{
  "dbAction": "I",
  "contentId": "EP000000510045",
  "seqNo": "0",
  "pgmGrId": "SH000000510000",
  "connectorId": "1013932",
  "serId": "184628",
  "serNo": "",
  "seasonId": "7895341",
  "seasonNo": "3",
  "pgmType": "Series",
  "realEpsdNo": "1",
  "summary": "Whitley encounters a new Dwayne on the plane ride back to school.",
  "pgmImgUrlName": "http://ngfts.lge.com/fts/gftsDownload.lge?biz_code=IBS&func_code=TMS_PROGRAM_IMG&file_path=/ibs/tms/program_img/p184628_b_v7_ab.jpg",
  "orgGenreType": "",
  "orgGenreCode": "188",
  "oGenreCode": "2",
  "oGenreType": "",
  "subGenreType": "",
  "subGenreCode": "",
  "makeCom": "",
  "makeCntry": "",
  "makeYear": "1989-09-28",
  "usrPplrSt": "",
  "pplrSt": "",
  "audLang": "en",
  "dataLang": "ENG",
  "audQlty": "",
  "genreImgUrl": "http://aic-ngfts.lge.com/fts/gftsDownload.lge?biz_code=IBS&func_code=GENRE_IMG&file_path=/ibs/genre_img_v/2_36_V_Sitcom.png",
  "vodFlag": "N",
  "pgmImgSize": "V480X720",
  "genreImgSize": "V480X704",
  "lgGenreCode2": "36",
  "lgGenreName2": "Sitcom",
  "programLock": "",
  "castingFlag": "Y"
}
```

<TODO description of attempts to hack>

#### application marketplace

bar

# impersonating

baz

## channel guide

barney

## application update

fizzbang