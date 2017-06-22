# Belkin Weemo Mini

- [device](#device)
- [digging](#digging)
  - [nmap](#nmap)


## device
name            | value
----------------|-----
model           | `Mini`
product         | `TODO`
firmware        | `TODO`
features        | WiFi enabled power strip

## digging

### nmap

from `nmap -PN -p 1-65535 -sV <device>`, we get:

```
PORT      STATE SERVICE VERSION
53/tcp    open  domain  dnsmasq 2.73
49152/tcp open  upnp    Belkin Wemo upnpd (UPnP 1.0)
Service Info: Device: power-misc
```

# TODO need to split this out, powerstrip is separate frome netcam

```
nmap 10.68.68.22 -Pn -sV -p 1-65535

Starting Nmap 7.12 ( https://nmap.org ) at 2017-04-04 17:02 PDT
Nmap scan report for CAM.ralinktech.com (10.68.68.22)
Host is up (0.030s latency).
Not shown: 65531 closed ports
PORT    STATE SERVICE  VERSION
53/tcp  open  domain   dnsmasq 2.40
80/tcp  open  http     Belkin NetCam http config
81/tcp  open  http     Belkin NetCam http config
443/tcp open  ssl/http Belkin NetCam http config
Service Info: Device: webcam
```



### upnpd

poking at this endpoint:

```
$ curl -v http://10.22.22.1:49152
* Rebuilt URL to: http://10.22.22.1:49152/
*   Trying 10.22.22.1...
* TCP_NODELAY set
* Connected to 10.22.22.1 (10.22.22.1) port 49152 (#0)
> GET / HTTP/1.1
> Host: 10.22.22.1:49152
> User-Agent: curl/7.51.0
> Accept: */*
>
< HTTP/1.1 404 Not Found
< SERVER: Unspecified, UPnP/1.0, Unspecified
< CONNECTION: close
< CONTENT-LENGTH: 48
< CONTENT-TYPE: text/html
<
* Curl_http_done: called premature == 0
* Closing connection 0
<html><body><h1>404 Not Found</h1></body></html>
```

`http://10.22.22.1:49152/foo` yields the same, but:

```

```

maybe we need to use [wemo-extracted/assets/api_key.txt](wemo-extracted/assets/api_key.txt) ?
 
digging into [constants.js](wemo-extracted/assets/www/js/constants.js), seeing some things we probably shouldn't:
```javascript
var cloudEnvironment = {
    /*CI: "https://173.196.160.173:8443",
    STAGING: "https://stagapi.xbcs.net:8443",
    PRODUCTION: "https://api.xbcs.net:8443",
    JARDEN: "https://api.test.jardon.xbcs.net:8443",
    QA: "https://173.196.160.163:8443",
    DEV: "https://173.196.160.173:8443"*/
		
    //adding urls with SSL certificates
    CI: "https://wemoci.lswf.net:9069",
    STAGING: "https://bcsstag.lswf.net:8443",
    PRODUCTION: "https://api.xbcs.net:8443",
    JARDEN: "https://api.test.jardon.xbcs.net:8443",
    QA: " https://wemoqa.lswf.net:9069",
    DEV: "https://wemoci.lswf.net:9069",
    MONOLITHIC: "https://devtest-1373897041.us-east-1.elb.amazonaws.com:8443"
};

/*var cloudEnvironment = {
    STAGING: "https://107.20.144.211:8443",
    PRODUCTION: "https://api.xbcs.net:8443"
};
*/

var firmwareCloudEnvironment = {
    STAGING: "http://fw.stag1.xbcs.net",
    PRODUCTION: "https://fw.xbcs.net",
    NESTDEV:"https://iftttnest.xwemo.com",
    JARDEN: "http://fw.test.jardon.xbcs.net",
    QA: "http://fw.xbcs.net",
    DEV: "http://173.196.160.173",
    CI: "http://173.196.160.173",
    MONOLITHIC: "https://fw.xbcs.net"
};

/*var firmwareCloudEnvironment = {
    STAGING: "http://75.101.183.196",
    PRODUCTION: "https://fw.xbcs.net"
};
*/

//...

var PUSH_DB_REQUIRED = 0;
var PUSH_DB_NOT_REQUIRED = 1;

var cloudAPI = {
    DEVICE_LIST: cloud + "/apis/http/plugin/plugins/",
    SMART_SETUP_REGISTRATION: cloud + "/apis/http/plugin/registration/smartDevice",
    STATE_CHANGE: cloud + "/apis/http/plugin/message/",
    ATTRIBUTE_CHANGE: cloud + "/apis/http/device/homeDevices/",
    // REGISTER_EMAIL: cloud + "/apis/http/plugin/registerEmail/",
    COLLECT_EMAIL: cloud + "/apis/http/plugin/emailAddresses/",
    FIRMWARE_URL: cloud + "/apis/http/plugin/fwUpgradeInfo/",
    SMARTDEVICE_DISABLE: cloud + "/apis/http/plugin/updateRemoteAccess/",
    SMARTDEVICE_LIST: cloud + "/apis/http/plugin/smartDevices/",
    GENERATE_IFTTT_PIN: cloud + "/apis/http/plugin/generatePin/",
    SEND_ACK_NEW_HOME: cloud + '/apis/http/plugin/ackForHomeIdSync/',
    DEVICE_MESSAGE: cloud + '/apis/http/plugin/message/',
    FIRMWARE_UPGRADE: cloud + '/apis/http/plugin/upgradeFwVersion',
    GET_DB_FILE: cloud + '/apis/http/plugin/dbfile/',
    LOCATION_SEARCH: cloud + '/apis/http/plugin/geoInfo/cityLocations?cityName=',
    INSIGHT_PARAMS: cloud + '/apis/http/plugin/insight/message/',
    SET_DEVICE_ICON: cloud + '/apis/http/plugin/ext/deviceIcon/',
    GET_DEVICE_ICON: cloud + '/apis/http/plugin/ext/deviceIcon/',
    GET_RULE_EVENTS: cloud + '/apis/http/plugin/push/ruleEvents/',
    LED_DEVICE_LIST: cloud + '/apis/http/device/homeDevices/',
    LED_STATE_CHANGE: cloud + '/apis/http/device/homeDevices/capabilityProfile?remoteSync=true',
    LED_CREATE_GROUP: cloud + '/apis/http/device/groups/',
    LED_DELETE_GROUP: cloud + '/apis/http/device/groups/',
    LED_STATE_CHANGE_GROUP: cloud + '/apis/http/device/groups/capabilityProfile?remoteSync=true',
    LED_EDIT_ICON: cloud + '/apis/http/lswf/uploads/',
    LED_GET_ICON: cloud + '/apis/http/device/homeUploads/',
    LED_FIRMWARE_URL: cloud + '/apis/http/device/fwUpgradeInfo/',
    EMAIL_OPT_IN: 'http://www.belkin.com/signup/wemo/?email',
    HIDE_DEVICE: cloud + '/apis/http/plugin/property/[MacAddress]/visibility/0'
};

var firmwareTextFile = {
    PATH: firmwareCloud + "/wemo/NewFirmware.txt",
    PATH_PROD: firmwareCloud + "/wemo/NewFirmware.txt",
    PATH_STAG: firmwareCloud + "/wemo/version.txt",
    PATH_QA: firmwareCloud + "/wemo/NewFirmware.txt",
    PATH_MINICLOUD: firmwareCloud + "/wemo/NewFirmware.txt",
    PATH_DEV:"http://173.196.160.173/wemo/NewFirmware.txt"
};
```

aside from the extremely amusing `PUSH_DB_REQUIRED` and `PUSH_DB_NOT_REQUIRED` values, looks like this could have the paths for new firmwares - allowing us to MiTM
