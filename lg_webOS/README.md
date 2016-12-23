# LG webOS

- [TV](#TV)
- [digging](#digging)
  - [nmap](#nmap)
  - [sniffing](#sniffing)
    - [on boot](#on-boot)
    - [channel search](#channel-search)
    - [application marketplace](#application-marketplace)
    - [license manager](#license-manager)
- [impersonating](#impersonating)
  - [OS update](#os-update)
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
$ curl -o foo "http://aic-ngfts.lge.com/fts/<path>"
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

`generate_slimmed-aic-json.rb` can be used to create a small schedule starting at the current time. 

#### application marketplace

bar

#### license manager

after an update of an application (and potentially other times), the device calls a different home:

request:
```
POST /license_manager.asp HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1;)
Host: us.security.lgtvsdp.com
Content-Length: 210
Content-Type:application/x-www-form-urlencoded
X-Device-Product:webOSTV 3.0
X-Device-Platform:W16P
X-Device-Model:HE_DTV_W16P_AFADATAA
X-Device-Netcast-Platform-Version:3.3.1
X-Device-Eco-Info:1
X-Device-Country-Group:US
X-Device-Publish-Flag:Y
X-Device-ContentsQA-Flag:Y
X-Device-FW-Version:04.30.40
X-Device-SDK-VERSION:3.3.1
X-Device-ID:<redacted>
X-Device-Type:T01
X-Device-Language:en-US
X-Device-Country:US
X-Device-Remote-Flag:N
X-Authentication:<redacted>


mode=issuelicense4pre&sid=1827712162&deviceid=<redacted>>&devicemodel=webostv&p=D1609DEB7189B744D4BC272550CBF5BF&g=5&A=52013FFC91EA5A6F41BE025B5E4461FB&hmac=OnSGJj7D3yth5HPdafdtnArDKYc%3D
```

nothing in the request really jumps out

response:
```
HTTP/1.1 200 OK
Cache-Control: private
Content-Length: 935
Content-Type: text/html
Server: Microsoft-IIS/7.5
Set-Cookie: ASPSESSIONIDAARCQAST=DOLHEFIBIEAONHPFCIFPECDL; path=/
X-Powered-By: ASP.NET
Date: Tue, 15 Nov 2016 19:00:39 GMT

<?xml version='1.0' encoding='utf-8'?><response result='0' message=''><responsedata>B=957172C7AF8EFA66326A7639D1C5301B;license=tDlsT2zdeFKZMZiOBv+pb9dSbyRclLkZJP4rw4Fv9tJYfqwbmE5kpDvHogWrC/yqMwlZG5tx+21PMV4zZDaYytZCZsfcJfLxHVFjU8MkfAOTtaPlUALmBvK/+jg4tGfE/LMoUGGle1huxAEM5UylS5zUA4yKa7V4XUgfFGde1ug9X3QzbnFH5oLMdmX7KyK3Z2HZ640kW/iGvPAz5lgZwvEx4I62aR7V0k/RbYMQfrC6jWHWVAz/yxNOOKSpMHK8tGNnGYoL9baiOh24jvoZ3lAvlLmPO/W8VmCZXRcmkTKuAvpej1fBFKzsRgfTci05MwqthA4caYxKGZhZdtWXJANzVE5V/2Xo35NG2lhwAEJmQoTP0ao6ygktdt+Eui6Ub4NIIn0WvpaNsQXkdhDnJ6ybpaXFy66KTevuJ7+/7N8E8RNF475EkF3FNuoVzNRTWxFmEk/IlMFVT0GgHh3q2sT8feNSo7usCYMLdnlDl15PDQ6894Weth6B+dbqe2xZk12qa7czTBlYAqjtH7oG2xg0G8N6vqrOHji8BkQ2zGnfqDmLq0OnFwlmUBu1GPyKpmsf+7pyuPEdVv8OI9TaEdqKw13IML6YVSJRHM7Q1hEpjwvbjttgk6XsJMvyVg7LMR3Fm1ZKOuRWbVrH/4j2fY5Nc6yek8y/aladiQnikoZ+CgSmvY58XsYu3Mo6J59X+z6jyUVka1/WhKAdVAHTUN2OZkH4rTYckgDMy3REXCU=;hmac=l0kBybteRX6bdSGjD/w0LV86MVU=</responsedata></response>
```

breaking down the XML response:

```xml
<?xml version='1.0' encoding='utf-8'?>
<response result='0' message=''>
  <responsedata>
    B=957172C7AF8EFA66326A7639D1C5301B;
    license=tDlsT2zdeFKZMZiOBv+pb9dSbyRclLkZJP4rw4Fv9tJYfqwbmE5kpDvHogWrC/yqMwlZG5tx+21PMV4zZDaYytZCZsfcJfLxHVFjU8MkfAOTtaPlUALmBvK/+jg4tGfE/LMoUGGle1huxAEM5UylS5zUA4yKa7V4XUgfFGde1ug9X3QzbnFH5oLMdmX7KyK3Z2HZ640kW/iGvPAz5lgZwvEx4I62aR7V0k/RbYMQfrC6jWHWVAz/yxNOOKSpMHK8tGNnGYoL9baiOh24jvoZ3lAvlLmPO/W8VmCZXRcmkTKuAvpej1fBFKzsRgfTci05MwqthA4caYxKGZhZdtWXJANzVE5V/2Xo35NG2lhwAEJmQoTP0ao6ygktdt+Eui6Ub4NIIn0WvpaNsQXkdhDnJ6ybpaXFy66KTevuJ7+/7N8E8RNF475EkF3FNuoVzNRTWxFmEk/IlMFVT0GgHh3q2sT8feNSo7usCYMLdnlDl15PDQ6894Weth6B+dbqe2xZk12qa7czTBlYAqjtH7oG2xg0G8N6vqrOHji8BkQ2zGnfqDmLq0OnFwlmUBu1GPyKpmsf+7pyuPEdVv8OI9TaEdqKw13IML6YVSJRHM7Q1hEpjwvbjttgk6XsJMvyVg7LMR3Fm1ZKOuRWbVrH/4j2fY5Nc6yek8y/aladiQnikoZ+CgSmvY58XsYu3Mo6J59X+z6jyUVka1/WhKAdVAHTUN2OZkH4rTYckgDMy3REXCU=;
    hmac=l0kBybteRX6bdSGjD/w0LV86MVU=
  </responsedata>
</response>
```

both `license` and `hmac` values are obviously hashes, but have been unable to determine what kind

# impersonating

most (all?) of this data is based on `impersonate-lge.rb` interactions

## OS update

`impersonate-lge.rb` catches the POST to `/CheckSWAutoUpdate.laf`, changes:

key                | value
-------------------|-----------------------------
`image_url`        | `http://snu.lge.com/fizbuzz`
`image_size`       | `400`
`image_name`       | `fizzbuzz`
`update_major_ver` | `04`
`update_minor_ver` | `30.50`
`force_flag`       | `Y`
`cdn_url`          | `http://snu.lge.com/fizzbuzz`
`contents`         | `''`

since the `update_minor_ver` specified is greater than the existing value (`30.40`), the TV prompts the user that an upgrade is available.

the traffic after the user chooses to upgrade:

```
```

<TODO finish this writeup and hack>

## channel guide

in `_public/aic/_source/slimmed/schedule.json`, changed:

key           | value
--------------|----
`schdSummary` | `h4ck the planet`
`schdPgmTtl`  | `h4ck the planet`
`schdSubTtl`  | `h4ck the planet`

in `_public/aic/_source/slimmed/program.json`, changed:

key             | value
----------------|----
`contentId`     | `EP022959710001`
`genreImgUrl`   | `http://aic-gfts.lge.com/aic/hacktheplanet.jpg`
`pgmGrId`       | `SH022959710000`
`pgmImgUrlName` | `http://aic-gfts.lge.com/aic/hacktheplanet.jpg`
`summary`       | `h4ck the planet`

`contentId` and `pgmGrId` were changed to make them line up with changes made to `schedule.json`

<TODO show interactions.. finish the writeup and the hack>


## application update

fizzbang