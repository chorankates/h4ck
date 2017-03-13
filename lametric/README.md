# time

- [device](#device)
- [digging](#digging)
  - [nmap](#nmap)
  - [curl](#curl)
  - [wireshark](#wireshark)
  - [mobile app](#mobile_app)
- [deeper](#deeper)
  - [API](#api)
  - [firmware](#firmware)
  - [UPNP](#upnp)

## device
name            | value
----------------|-----
model           | `LM 37X8`
product         | `CLOCK`
firmware        | API `2.0.0`, OS `1.7.1`
features        | WiFi enabled clock

the `TIME LM 37X8` is a 'smart' clock that features:
  * internet connectivity to download apps, exchange information
  * bluetooth controller to use the internal speaker
  * clock with multiple alarms
  * web radio tuner
  * timer
  * stopwatch

initial configuration is similar to Chromecast's, it stands up a WiFi network named `LM7***` based on the serial number of the device.

download the Android/iOS lamteric app and walk through connecting it to another wireless network - they do some external access checks with:
  * `ntp` requests to `0.pool.ntp.org`
  * `dns` resolution of `developer.lametric.com`
  * `icmp` requests to `developer.lametric.com`

which has made tricking the device into talking to another endpoint has been unsuccessful so far, as it also appears to do SSL certification verification, so sslstrip isn't seeing anything.

through lametric's [developer site](https://developer.lametric.com/), once the device is registered, the API key necessary for talking to the device is displayed

## digging

### nmap

from `nmap -PN -p 1-65535 -sV 172.16.42.219`, we get:

```
PORT     STATE SERVICE VERSION
22/tcp   open  ssh         Dropbear sshd 2014.66 (protocol 2.0)
80/tcp   open  http        lighttpd 1.4.35
443/tcp  open  http        lighttpd 1.4.35
4343/tcp open  ssl/http    lighttpd 1.4.35
8080/tcp open  http        lighttpd 1.4.35
9001/tcp open  tor-orport?
9002/tcp open  dynamid?
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

ssh, 4 web servers (likely 2, one each of HTTP and HTTPS), 2 unknowns and a Linux fingerprint. for a clock.

### curl

#### 80 -> 443

```
$ curl -k -vv http://172.16.42.219
* Rebuilt URL to: http://172.16.42.219/
*   Trying 172.16.42.219...
* TCP_NODELAY set
* Connected to 172.16.42.219 (172.16.42.219) port 80 (#0)
> GET / HTTP/1.1
> Host: 172.16.42.219
> User-Agent: curl/7.51.0
> Accept: */*
>
< HTTP/1.1 401 Unauthorized
< WWW-Authenticate: Basic realm="global"
< Content-Type: application/json;charset=UTF8
< Content-Length: 96
< Date: Fri, 10 Mar 2017 23:58:22 GMT
< Server: lighttpd/1.4.35
<
{
    "errors":[
        {
            "message":"Authorization is required"
        }
    ]
}

* Curl_http_done: called premature == 0
* Connection #0 to host 172.16.42.219 left intact
```

so something is listening there, and it's spitting back JSON, but we don't have credentials yet.

#### 4343

```
$ curl https://172.16.42.219:4343 -k -vv
* Rebuilt URL to: https://172.16.42.219:4343/
...
< HTTP/1.1 404 Not Found
< Content-Type: application/json;charset=UTF8
< Content-Length: 67
< Date: Fri, 10 Mar 2017 22:22:18 GMT
<
{
    "errors":[
        {
            "message":"Resource not found"
        }
    ]
}
```

different port, potentially the same underlying service/data, but this time - does not appear to require credentials.


### wireshark

see some communication between the device and it's mobile app:

```
GET /<redacted>/device_description.xml HTTP/1.1
Connection: close
Accept-Encoding: gzip
User-Agent: Google-HTTP-Java-Client/1.22.0 (gzip)
Host: 172.16.42.219:43316

HTTP/1.1 200 OK
DATE: Fri, 10 Mar 2017 16:06:04
Connection: close
HOST: 172.16.42.219:43316
content-length: 791

<?xml version="1.0" encoding="UTF-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <URLBase>https://172.16.42.219:443</URLBase>
  <device>
    <deviceType>urn:schemas-upnp-org:device:LaMetric:1</deviceType>
    <friendlyName>LaMetric (LM7817)</friendlyName>
    <manufacturer>LaMetric Inc.</manufacturer>
    <manufacturerURL>http://www.lametric.com</manufacturerURL>
    <modelDescription>LaMetric - internet connected clock and smart display</modelDescription>
    <modelName>LaMetric Time Battery Edition</modelName>
    <modelNumber>SA01</modelNumber>
    <modelURL>http://www.lametric.com</modelURL>
    <serialNumber><redacted></serialNumber>
    <serverId>10478</serverId>
    <deviceId>10478</deviceId>
    <UDN>uuid:<redacted></UDN>
  </device>
</root>
```

this port seems to change, but is easy to find as is part of an SSDP [UPNP broadcast](#upnp)

### mobile app

by changing the weather settings, we see:
```
GET /premium/v1/weather.ashx?q=<parameters> HTTP/1.1
Host: api.worldweatheronline.com
Accept: */*
```

parameters broken down:
```
Potrero District, United States of America&
num_of_days=2&
format=json&
fx=yes&
cc=yes&
mca=no&
fx24=no&
tp=24&
includelocation=yes&
showlocaltime=yes&&
extra=isDayTime,utcDateTime&
key=<redacted>
```

looks like a premium API key to [world weather online](worldweatheronline.com)

## deeper

### API

looking at some [docs](http://lametric-documentation.readthedocs.io/en/latest/reference-docs/lametric-time-reference.html) from lametric, was able to determine that the api lives at `http://device:port/api/v2`

authing with `dev` and `\<api key\>`, was got the expected list of routes:

```json
{
  "api_version": "2.0.0",
  "endpoints": {
    "audio_url": "https://172.16.42.219:4343/api/v2/device/audio",
    "bluetooth_url": "https://172.16.42.219:4343/api/v2/device/bluetooth",
    "concrete_notification_url": "https://172.16.42.219:4343/api/v2/device/notifications{/:id}",
    "current_notification_url": "https://172.16.42.219:4343/api/v2/device/notifications/current",
    "device_url": "https://172.16.42.219:4343/api/v2/device",
    "display_url": "https://172.16.42.219:4343/api/v2/device/display",
    "notifications_url": "https://172.16.42.219:4343/api/v2/device/notifications",
    "widget_update_url": "https://172.16.42.219:4343/api/v2/widget/update{/:id}",
    "wifi_url": "https://172.16.42.219:4343/api/v2/device/wifi"
  }
}
```

cool, so we can talk to the API successfully now - unfortunately, there isn't much that appears interesting on the surface, at least from an attack vector.

`curl --user dev:<api_key> https://<device>/api/v2/device`
```json
{
  "audio": {
    "volume": 46
  },
  "bluetooth": {
    "active": false,
    "address": "<redacted>",
    "available": true,
    "discoverable": false,
    "name": "LM7817",
    "pairable": true
  },
  "display": {
    "brightness": 100,
    "brightness_mode": "auto",
    "height": 8,
    "type": "mixed",
    "width": 37
  },
  "id": "10478",
  "mode": "manual",
  "model": "LM 37X8",
  "name": "LM7817",
  "os_version": "1.7.1",
  "serial_number": "<redacted>",
  "wifi": {
    "active": true,
    "address": "<redacted>",
    "available": true,
    "encryption": "open",
    "essid": "home",
    "ip": "172.16.42.219",
    "mode": "dhcp",
    "netmask": "255.255.255.0",
    "strength": 100
  }
}

```

### firmware

searching around for their [firmware](https://developer.lametric.com/getfirmware/download), the latest version shown was 1.7.7 - apparently they version OS and API separately.

binwalk shows us that the file is a nested squashfs:

```
$ binwalk -t -v -e <file>

DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------------------------------------
0             0x0             Squashfs filesystem, little endian, version 4.0, compression:gzip, size:
                              79064386 bytes, 8 inodes, blocksize: 131072 bytes, created: 2017-03-06 17:58:17

$ sudo unsquashfs <file>
...
created 7 files
created 1 directories
created 0 symlinks
created 0 devices
created 0 fifos
$ ls squashfs-root/
rootfs.squash           rootfs.squash.sig    update.conf.sig
rootfs.squash.md5       update.conf          update.conf.md5

$ cd squashfs-root
$ sudo unsquashfs squashfs-root
...
created 3697 files
created 675 directories
created 930 symlinks
created 253 devices
created 0 fifos
$ ls squashfs-root/
bin             home            libexec         opt             sbin            usr
boot            lametric        linuxrc         proc            sys             var
dev             lib             media           root            tests
etc             lib32           mnt             run             tmp
```

now we're getting somewhere.

```
$ head -n 1 etc/shadow
root:<redacted>:10933:0:99999:7:::
```

started cracking at 5:30 on 2017/03/10, and as of 2017/03/12, the GCP instance has been unable to crack the password hash. soon.gif

```
$ cat lametric/system/services/com.lametric.api/.api
[FastCGI]
portNumber=9001
socketType=FCGI-TCP

$ cat lametric/system/services/com.lametric.push.api/.push_api
[FastCGI]
portNumber=9002
socketType=FCGI-TCP

$ cat lametric/system/gui/com.lametric.notification_server/settings.json
{
    "smtp_credentials": {
    },
    "filter_folder" : "Inbox",
    "filter_emails" : ["lsqateam@gmail.com","lsqateam2@gmail.com"],
    "filter_keywords" : ["lametric","money"],
    "counter_all" : true,
    "counter_unread" : true,
    "show_subject" : true
}

$ cat etc/lighttpd/pushes/conf.d/fastcgi.conf
fastcgi.debug = 1
fastcgi.server = (
    "/" => (
       "/" => (
        "host" => "127.0.0.1",
        "port" => "9002",
        "check-local" => "disable",
        "min-procs" => 1,
        "max-procs" => 1,
        "idle-timeout" => 30,
        "fix-root-scriptname" => "enable",
        "allow-x-send-file" => "enable"
      )
    )
  )

$ cat etc/lighttpd/pushes/conf.d/auth.conf
## type of backend
# plain, htpasswd, ldap or htdigest
auth.backend               = "plain"

# filename of the password storage for plain
auth.backend.plain.userfile = "/lametric/data/configs/lighttpd/users.txt"

## for htpasswd
#auth.backend.htpasswd.userfile = "/lametric/data/configs/lighttpd/users.txt"

$ cat etc/init.d/S25install
...
  # Checking if it is not empty
  if [ "$(ls -A $IPK_SRC_DIR)" ]; then

     PACKAGES=$(ls $IPK_SRC_DIR/*.ipk)

     # for each ipk file do installation
     for entry in $PACKAGES
     do
        echo Installing $entry
        opkg-cl install $entry
        if [ "$?" != "0" ]; then
     echo Error installing $entry. Code $?
     echo timestamp Error installing $entry, code $? >> /tmp/install.errlog
        fi

        # remove file after installation
        rm $entry
     done
  done
...

$ cat etc/init.d/S31changeUserData
...
start() {
    chmode 777 /lametric/data/data
}
...

$ cat etc/init.d/S99defwidgets
...
        echo "Creating default widgets..."
        su - app -s /bin/sh -c "/usr/bin/widget.sh create com.lametric.clock 08b8eac21074f8f7e5a29f2855ba8060"
        su - app -s /bin/sh -c "/usr/bin/widget.sh create com.lametric.weather 380375c4b12c16e3adafb48355ba8061"
        su - app -s /bin/sh -c "/usr/bin/widget.sh create com.lametric.radio 589ed1b3fcdaa5180bf4848e55ba8061"
        su - app -s /bin/sh -c "/usr/bin/widget.sh create com.lametric.stopwatch b1166a6059640bf76b9dfe0455ba8062"
        su - app -s /bin/sh -c "/usr/bin/widget.sh create com.lametric.countdown f03ea1ae1ae5f85b390b460f55ba8061"


$ cat etc/init.d/S99devicestatus
...
        BLUETOOTH_MAC_ADDRESS=$(cat /sys/class/bluetooth/hci0/address)
        WIFI_MAC_ADDRESS=$(cat /sys/class/net/wlan0/address)
        WIFI1_MAC_ADDRESS=$(cat /sys/class/net/wlan1/address)
        SD_CARD_SIZE=$(expr `cat /sys/block/mmcblk0/size` \* 512)

$ cat etc/lametric-tools/recovery.conf
# Device for keyboard input
input=/dev/input/event1

$ cat etc/lighttpd/lighttpd.conf
...
$SERVER["socket"] == ":4343" {
    ssl.engine = "enable"
    ssl.pemfile = "/etc/security/CA/server.pem"
}
$SERVER["socket"] == ":8080" {
    ssl.enable = "disable"
}

$ cat etc/ssh/sshd_config
...
# The default is to check both .ssh/authorized_keys and .ssh/authorized_keys2
# but this is overridden so installations will only check .ssh/authorized_keys
AuthorizedKeysFile  /lametric/data/configs/.ssh/authorized_keys

$ cat etc/system.conf

# LaMetric filesystem structure
LAMETRIC_ROOT=/lametric
LAMETRIC_SYSTEM=/lametric/system/services
LAMETRIC_SYSTEM_GUI_APPS=/lametric/system/gui
LAMETRIC_PREINSTALLED_APPS=/lametric/system/apps
LAMETRIC_APPS=/lametric/data/apps
LAMETRIC_WIDGETS=/lametric/data/widgets
LAMETRIC_DATA=/lametric/data/data
LAMETRIC_CONFIGS=/lametric/data/configs
LAMETRIC_FORMAT_FLAG_FILE_NAME=/lametric/data/FORMAT_PARTITION

FIRMWARE_FILE_REGEXP=lm_ota_[a-z0-9._]*_sa1.bin

$ ls lametric/system/apps/com.lametric.radio/res/*.png
lametric/system/apps/com.lametric.radio/res/next.png
lametric/system/apps/com.lametric.radio/res/play.png
lametric/system/apps/com.lametric.radio/res/radio.png
lametric/system/apps/com.lametric.radio/res/screen1.png
lametric/system/apps/com.lametric.radio/res/stop.png

$ find usr/share/sounds/lametric -iname '*.wav' | wc -l
      54

$ cat lametric/system/gui/com.lametric.broken_app/settings.json
...
{
  "version":1,
  "alarms" : [ {
    "name" : "Alarm 1",
    "time" : "15:22:49",
    "enabled" : true,
    "sound" : {
      "source":"system",
      "id":"sound1"
    },
    "daysofweek" : ["sun","mon","tue","wed","fri","sat"]
  }],
  "timezone" : "Europe/Kiev",
  "timeformat24h" : true,
  "seconds" : true,
  "display_date" : false,
  "dayofweek" : true,
  "locale":"en_US"
}
...

$ cat usr/lib/xml2Conf.sh
...
XML2_LIBS="-lxml2 -L/var/lib/jenkins/jobs/LaMetric_Image_DVT/workspace/main_image/host/usr/arm-buildroot-linux-gnueabi/sysroot/usr/lib -lz   -lm "
...

$ cat usr/share/tests/LEDMatrix.sh
#! /bin/sh

lmledtool -t &> /dev/null
var=$?
return $var


```

lots of interesting bits:
  * what look like lametric QA email addresses
  * despite ability to use htpasswd or htdigest, they use plaintext
  * automatically installs `/etc/install/*.ipk`
  * automatically makes all application configuration data readable by all users
  * 2 wifi controllers allow for it to act as a hotspot
  * it's using an SD card as primary (?) storage
  * it has a keyboard controller, does not appear specific to the 3 buttons
  * like most devices, has an easily accessible glob/regex of 'allowed' firmware names
  * why is there an alarm set for `15:22:49`?
  * what is the test that happens when we run `lmledtool -t`

unfortunately, many of the files mentioned live in `/lametric/data/configs` which is mostly unpopulated in the firmware squashfs, so will need to revisit once the root hash is cracked.

### UPNP

```xml
<?xml version="1.0" encoding="UTF-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <URLBase>https://172.16.42.219:443</URLBase>
  <device>
    <deviceType>urn:schemas-upnp-org:device:LaMetric:1</deviceType>
    <friendlyName>LaMetric (LM7817)</friendlyName>
    <manufacturer>LaMetric Inc.</manufacturer>
    <manufacturerURL>http://www.lametric.com</manufacturerURL>
    <modelDescription>LaMetric - internet connected clock and smart display</modelDescription>
    <modelName>LaMetric Time Battery Edition</modelName>
    <modelNumber>SA01</modelNumber>
    <modelURL>http://www.lametric.com</modelURL>
    <serialNumber><redacted></serialNumber>
    <serverId>10478</serverId>
    <deviceId>10478</deviceId>
    <UDN>uuid:<redacted></UDN>
  </device>
</root>
```
