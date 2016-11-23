# LG webOS

- [TV](#TV)
- [digging](#digging)
  - [nmap](#nmap)
  - [sniffing](#sniffing)
    - [on boot](#onboot)
    - [channel search](#channelsearch)
    - [application marketplace](#applicationmarketplace)
- [impersonating](#impersonating)
  - [channel guide](#channelguide)
  - [application update](#applicationupdate)

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
was rooting the device, but initial investigations showed some other interesting vectors.

## digging

### nmap

from `nmap -PN -sV <device`, we get:

```
PORT     STATE SERVICE  VERSION
1175/tcp open  upnp
3000/tcp open  http     LG smart TV http service
3001/tcp open  ssl/http LG smart TV http service
9998/tcp open  http     Google Chromecast httpd
```

aside from the obvious flag running of both HTTP and HTTPS versions of (likely) the same service,
interested to see that the Chromecast plugged in to the TV is also being exposed on the same IP as the TV.

since there is an [LG smart TV](TODO) app available for Android/iOS, assuming that there is an API of some sort running on `3000` or `3001`, so:

```
$ curl http://<device>:3000
Hello world
```

we see the same response on `3001`, but have to use `-k` as the device uses a self-signed certificate.

so, something is there, we just don't know how to talk to it yet.

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


half an hour of playing around with both the input and output here didn't yield any immediate results, but there is definite potential.

to speed this along, observe a session where the TV updated its firmware from the manufacturer 

#### channel search

foo

#### application marketplace

bar

# impersonating

baz

## channel guide

barney

## application update

fizzbang