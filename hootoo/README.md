hoo2
====

- [devices](#devices)
	- [TripMate Titan](#tripmate-titan)
		- [nmap](#nmap)
		- [easily guessable default passwords](#easily-guessable-default-passwords)
		- [universal root password](#universal-root-password)
		- [credential exposure - WiFi network and bridge](#credential-exposure-wifi-network-and-bridge)
		- [data exposure - NAS](#data-exposure-nas)
		- [interesting URLs](#interesting-urls)
		  - [protocol.csp](#protocolcsp)
	- [TripMate](#tripmate)
		- [nmap](#nmap)
		- [upgrading is hard](#upgrading-is-hard)
	- [TripMate Elite](#tripmate-elite)
		- [nmap](#nmap)
	- [TripMate Nano](#tripmate-nano)
		- [nmap](#nmap)
	- [HooToo IPCam](#hootoo-ipcam)
		- [nmap](#nmap)

i was initially interested in the HooToo TripMate Titan when someone on Twitter (thought it was @davepell, but can't find the tweet now) saying it was a great way to share battery/network/data from a single device.

that sounds cool - not just for the surface use cases: road trips, airplane flights, etc - but also because the features required meant the TripMate was a $39 low power, wifi enabled computer with it's own battery. <insert cheesy Zuckerberg misquote here>

my goal was always to gain access to this device in ways it's manufacturer hadn't intended, but what i found was a bit excessive.

some of the issues are as common as XSS vulnerabilities, others as serious as passing credentials/settings in plaintext over HTTP and a universally reused root password.

* after testing the [rav-filehub](rav-filehub), found that calling an-api-method-not-exposed-by-the-ui would allow download of a ['backup'](http://10.10.10.254:81/sysfirm.csp?fname=sysbackupform&t=1467949779552). i haven't tried POSTing it back, but assume it would work.

# devices
name|model|description|version|rooted?|services|vulnerabilities
----|-----|-----------|-------|-------|--------|---------------
[TripMate Titan](http://www.hootoo.com/hootoo-tripmate-ht-tm05-wireless-router.html)|HT-TM05|NAS/WiFi bridge/battery| firmware: `2.000.022`|yes|`telnet`, `http (80, 81)`, `unknown 85, 8200)`|easily guessable default passwords, universal root password, credential exposure, data exposure, HTTP - variety
[TripMate](http://www.hootoo.com/hootoo-tripmate-ht-tm01-wireless-router.html)|HT-TM01|NAS/WiFi bridge/battery| firmware: `2.000.022`|yes|`telnet`, `http (80, 81)`|same as TripMate Titan
[TripMate Elite](http://www.hootoo.com/hootoo-tripmate-elite-ht-tm04-wireless-portable-router.html)|HT-TM06|NAS/WiFi bridge/battery/outlet|firmware: `2.000.004`|no|`http (80, 81)`|easily guessable default passwords, HTTP - variety
[TripMate Nano](http://www.hootoo.com/hootoo-tripmate-nano-ht-tm02-wireless-portable-router.html)|HT-TM02|NAS/WiFi bridge| firmware: `2.000.018`|yes|`telnet`, `http (80, 81)`, `unknown 85`|same as TripMate Titan
[Hootoo IPCam]()|RT_IPC6000|IP camera| firmware: `V2.5.5.2505-S50-HTA-B20151208B` |yes|`telnet`, `http`, `RTSP 554`|almost the same as TripMate Titan

while both TripMate Titan and TripMate are running the same version of firmware, and have the same services exposed, the web interfaces are very different.

despite the striking similarities between the underlying platforms, it appears they all rev firmware versions differently. currently, the latest TripMate Titan version is [2.000.068](http://www.hootoo.com/media/downloads/HooToo%20TM05-Support%20exFAT&HFS%20-%202.000.068.rar), whereas the TripMate is only up to [2.000.036](http://www.hootoo.com/media/downloads/fw-ban%20WAN%20access-%20HooToo-%20TM01-2.000.036.zip).

see [upgrades-are-hard](upgrades are hard) for a tale of firmware version changes while trying to test the most recent versions.

## TripMate Titan
name|value
----|-----
model|HT-TM05
firmware|2.000.022
features|WiFi bridge, NAS, battery
app|[http://10.10.10.254](http://10.10.10.254)

this was the first HooToo device i looked at, and most of the issues found on this device are shared across the rest of the products - the Elite and ipCAM being notable exceptions.

all of the non-HTTP issues started with a simple nmap of the device.

### nmap
```
PORT   STATE SERVICE    VERSION
23/tcp open  telnet     NASLite-SMB/Sveasoft Alchemy firmware telnetd
80/tcp open  http       lighttpd
81/tcp open  http       Web-Based Enterprise Management CIM serverOpenPegasus WBEM httpd
85/tcp open  tcpwrapped
8200/tcp open  trivnet1?
Service Info: Host: HT-TM05; OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

couple of quick observations:
  * running a telnet server?
  * running 2 HTTP servers?

it turns out that both [http://10.10.10.254:80](http://10.10.10.254:80) and [http://10.10.10.254:81](http://10.10.10.254:81) are both serving the exact same content - but backed by different web servers (`lighttpd` and `OpenPegasus WBEM CIM`)


### easily guessable default passwords

realm|username|password|description
-----|--------|--------|------------
WiFi|n/a|`12345678`|this is changeable, but the option is buried
app|admin|`<empty>`|allows login to web app ([default](http://10.10.10.254))

### universal root password

while not easily guessable, the `root` password is trivial to obtain:

```
$ telnet 10.10.10.254
Trying 10.10.10.254...
Connected to 10.10.10.254.
Escape character is '^]'.

HT-TM05 login: admin
Password:
login: can't chdir to home directory '/data/UsbDisk1/Volume1'
$ ls -l /etc/passwd /etc/shadow
-rw-r--r--    1 root     root          406 Jan  1 00:02 /etc/passwd
-rw-r--r--    1 root     root          282 Jan  1 00:02 /etc/shadow
```

so.. they left `/etc/passwd` and `/etc/shadow` readable to anyone who can login - and the web app uses the same credential mechanism as telnet/underlying OS.

now that we've got it, 5 hours on a GCP v16 CPU instance, we find that the password behind `$1$yikWMdhq$cIUPc1dKQYHkkKkiVpM` is `20080826`.

and now, we can login to both the web app and telnetd as `root`:
```
$ telnet 10.10.10.254
Trying 10.10.10.254...
Connected to 10.10.10.254.
Escape character is '^]'.

HT-TM05 login: root
Password:
login: can't chdir to home directory '/root'
#
```

#### credential exposure - WiFi network and bridge

# TODO what are the perms on that file?

the contents of `/boot/tmp/etc/Wireless/RT2860/RT2860.dat` compromise:
  * plaintext password for device SSID
  * SSID of last/currently bridged WiFi network
  * plaintext password for last/currently bridged WiFi network

```
# cat /boot/tmp/etc/Wireless/RT2860/RT2860.dat
...
SSID1=free candy
...
WPAPSK1=foobarbaz
...
ApCliSsid1=test-network
ApCliWPAPSK=password
```

#### data exposure - NAS

without really explaining it or documenting it, the TripMate assumes that the USB storage device you plugin will have a directory called `Share` in it's root, with `Music`, `Pictures` and `Videos` directories under that. if you don't, it will happily create them for you.

i put some content in the appropriate path, and when walking through the Music player, it sent me to `http://10.10.10.254/data/UsbDisk1/Volume1/Share/Music/Girl%20Talk%20-%20Feed%20The%20Animals/14%20Play%20Your%20Part%20%28Pt.%202%29.mp3`

working URLs:
  * `http://10.10.10.254/data/UsbDisk1/Volume1/Share/` - not necessarily bad, just unexpected
  * `http://10.10.10.254/data/UsbDisk1/Volume1/` - this is an implied vulnerability
  * `http://10.10.10.254/data/` - another implied vulnerability.. could we link something into this directory and get browsable access that way?


#### interesting URLs

# TODO need to add context here

* `http://10.10.10.254//index.csp?fname=logout`
* `http://10.10.10.254/protocol.csp?fname=net&opt=led_status&function=get`
* `http://10.10.10.254/protocol.csp?fname=storage&opt=listen_disk&function=get`
* `http://10.10.10.254/protocol.csp?fname=system&opt=i2c&function=get`
* `http://10.10.10.254/protocol.csp?fname=security&opt=userlock&function=set`
* `http://10.10.10.254/protocol.csp?function=set` -

parameters:
  * name
  * pwd1

# TODO need to talk about GET vs POST here

* `http://10.10.10.254/themes/HT-TM05/lge/us.js` - error code to message mapping
* when no internet connection is available, all HTTP requests are blindly 301'd to [http://10.10.10.254/app/main.html](http://10.10.10.254/app/main.html)
* [hootoo.com's 404](http://www.hootoo.com/foobarbaz) page is .. amusing

#### protocol.csp
fname|opts
-----|----
net  | [led_status](http://10.10.10.254/protocol.csp?fname=net&opt=led_status&function=get), [waninfo](http://10.10.10.254/protocol.csp?fname=net&opt=led_status&function=get)
pwdcheck | \<none, uses name/pwd1\>
security | [userlock](http://10.10.10.254/protocol.csp?fname=security&opt=userlock&function=post), [dirlist](http://10.10.10.254/protocol.csp?fname=security&opt=dirlist&function=get)
storage | [listen_disk](http://10.10.10.254/protocol.csp?fname=storage&opt=listen_diskt&function=get), [partopt](http://10.10.10.254/protocol.csp?fname=storage&opt=partopt&function=get), [disk](http://10.10.10.254/protocol.csp?fname=storage&opt=disk&function=get), [usbremove](http://10.10.10.254/protocol.csp?fname=storage&opt=usbremove&function=post)
system | i2c, host, devinfo, cpu, autoupdate, curtype

have not done enough digging in this area, but several of these opts accept `function=set`, potentially allowing for DOS attacks.

## TripMate

### nmap
```
Starting Nmap 6.46 ( http://nmap.org ) at 2016-06-29 20:45 PDT
Nmap scan report for 10.10.10.254
Host is up (0.026s latency).
Not shown: 997 closed ports
PORT   STATE SERVICE VERSION
23/tcp open  telnet  NASLite-SMB/Sveasoft Alchemy firmware telnetd
80/tcp open  http    lighttpd
81/tcp open  http    Web-Based Enterprise Management CIM serverOpenPegasus WBEM httpd
Service Info: Host: TM01; OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
### upgrading is hard

when i tried to upgrade the TripMate, i failed with an error message `No available space`, which seemed odd.

```
// 'No available space'
# df -h
Filesystem                Size      Used Available Use% Mounted on
rootfs                    5.3M      5.3M         0 100% /
/dev/root                 5.3M      5.3M         0 100% /

// 'The system is being upgraded. Please wait 5 minutes. Remaining <n> seconds …After the upgrade is successful,reconnect the device Wi-Fi.'
# df -h
Filesystem                Size      Used Available Use% Mounted on
rootfs                    5.3M      5.3M         0 100% /
/dev/root                 5.3M      5.3M         0 100% /
/dev/sda1                 3.8G   1020.0k      3.8G   0% /data/UsbDisk1/Volume1
```

despite the firmware upgrade.. going on the firmware, rather than uploading to tmpfs (as `free` shows ). after the upgrade, the SSID was changed to `TripMate-855C`, and unfortunately, the `telnet` hole was closed - and in it's place, a 404 behind:
  * User Manager -> Guest
  * Network Settings -> Hostname
  * Network Settings -> WiFi & latency
  * Network Settings -> DHCP Server
  * Network Settings -> Internet
  * Service Settings -> Samba Service
  * Service Settings -> DLNA Service
  * Service Settings -> Auto-jump Service
  * System Settings -> Time Settings
  * System Settings -> Firmware Upgrade
  * System Settings -> Reset Settings
  * Setup Wizard

so every option other than User Manager -> Admin.. on the web interface that's running on port 80. however, the interface that is running on port 81 gives us all of the options back - assuming you know it is there.


## TripMate Elite

### nmap
```
Starting Nmap 6.46 ( http://nmap.org ) at 2016-06-29 20:49 PDT
Nmap scan report for 10.10.10.254
Host is up (0.0096s latency).
Not shown: 998 closed ports
PORT   STATE SERVICE VERSION
80/tcp open  http    lighttpd
81/tcp open  http    Web-Based Enterprise Management CIM serverOpenPegasus WBEM httpd
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## TripMate Nano

### nmap
```
Starting Nmap 6.46 ( http://nmap.org ) at 2016-06-29 20:41 PDT
Nmap scan report for 10.10.10.254
Host is up (0.018s latency).
Not shown: 996 closed ports
PORT   STATE SERVICE    VERSION
23/tcp open  telnet     NASLite-SMB/Sveasoft Alchemy firmware telnetd
80/tcp open  http       lighttpd
81/tcp open  http       Web-Based Enterprise Management CIM serverOpenPegasus WBEM httpd
85/tcp open  tcpwrapped
Service Info: Host: TM02; OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Hootoo IPCam
name|value
----|-----
model|RT_IPC6000
firmware|`V2.5.5.2505-S50-HTA-B20151208B`
features|IP camera with a surprisingly high level of configuration
app|[http://10.10.10.254](http://10.10.10.254)

while this device appears to be running a similar firmware/OS as the TripMate devices, and has similar services exposed, could not login via telnet with `root` or `admin`

the user specification page allows freeform username specification, tried to set `root`s password, but either failed, or was given a misleading error message from telnet.

the backup functionality here exposes a similar hole (configuration/files unrelated to user settings) as TripMate devices, but has a very different structure/content:

```
.
├── mnt
│   └── config
│       ├── exclude.lst
│       ├── ipcamera
│       │   ├── TZ
│       │   ├── adsl.conf
│       │   ├── bt656
│       │   │   ├── config_av.ini
│       │   │   ├── config_enc.ini
│       │   │   ├── config_md.ini
│       │   │   ├── config_mpmng.ini
│       │   │   └── config_od.ini
│       │   ├── conf_1080p
│       │   │   ├── config_cfgaccess.ini
│       │   │   ├── config_devm.ini
│       │   │   └── config_mpmng.ini
│       │   ├── conf_720p
│       │   │   ├── config_cfgaccess.ini
│       │   │   ├── config_devm.ini
│       │   │   └── config_mpmng.ini
│       │   ├── conf_960p
│       │   │   ├── config_cfgaccess.ini
│       │   │   ├── config_devm.ini
│       │   │   └── config_mpmng.ini
│       │   ├── conf_TrigOprt.ini
│       │   ├── conf_jsy
│       │   │   └── jsy.ini
│       │   ├── conf_tutk
│       │   │   └── tutk.ini
│       │   ├── config_alarmweb.ini
│       │   ├── config_button.ini
│       │   ├── config_capability.ini
│       │   ├── config_cd.ini
│       │   ├── config_cfgaccess.ini
│       │   ├── config_devm.ini
│       │   ├── config_electricity.ini
│       │   ├── config_emng.ini
│       │   ├── config_enc_workmode.ini
│       │   ├── config_ioalm.ini
│       │   ├── config_ircut.ini
│       │   ├── config_led.ini
│       │   ├── config_log.ini
│       │   ├── config_mail.ini
│       │   ├── config_maintenance.ini
│       │   ├── config_mtmng.ini
│       │   ├── config_mwalm.ini
│       │   ├── config_notify.ini
│       │   ├── config_ntp.ini
│       │   ├── config_osd.ini
│       │   ├── config_piclevel.ini
│       │   ├── config_playaudio.ini
│       │   ├── config_ptz.ini
│       │   ├── config_rec.ini
│       │   ├── config_recmng.ini
│       │   ├── config_rfidlist.ini
│       │   ├── config_server.ini
│       │   ├── config_snap_function.ini
│       │   ├── config_snap_mng.ini
│       │   ├── config_soundalm.ini
│       │   ├── config_sysalm.ini
│       │   ├── config_timer_mng.ini
│       │   ├── config_upnp.ini
│       │   ├── config_user.ini
│       │   ├── config_usergroup.ini
│       │   ├── ddns.conf
│       │   ├── ddns_enable.conf
│       │   ├── factory.conf
│       │   ├── fwup.conf
│       │   ├── hi_nvt_config
│       │   │   ├── audio_encoder_configuration.ini
│       │   │   ├── audio_source.ini
│       │   │   ├── audio_source_configuration.ini
│       │   │   ├── profile.ini
│       │   │   ├── ptz_configuration.ini
│       │   │   ├── scopes_list.ini
│       │   │   ├── video_encoder_configuration.ini
│       │   │   ├── video_source.ini
│       │   │   └── video_source_configuration.ini
│       │   ├── ipc1080p
│       │   │   ├── config_av.ini
│       │   │   ├── config_enc.ini
│       │   │   ├── config_md.ini
│       │   │   ├── config_mpmng.ini
│       │   │   └── config_od.ini
│       │   ├── ipc6000
│       │   │   ├── config_av.ini
│       │   │   ├── config_enc.ini
│       │   │   ├── config_md.ini
│       │   │   ├── config_mpmng.ini
│       │   │   └── config_od.ini
│       │   ├── ipcam_upnp.xml
│       │   ├── keypara.ini
│       │   ├── network
│       │   │   ├── interfaces.old
│       │   │   ├── netfaces
│       │   │   ├── resolv.conf
│       │   │   ├── setfixnet.sh
│       │   │   ├── wifi.conf
│       │   │   ├── wifidev.conf
│       │   │   ├── wpa_supp.conf
│       │   │   └── zcip.script
│       │   ├── onvif.ini
│       │   ├── p2p.conf
│       │   ├── p2p_stream.ini
│       │   ├── savetime.conf
│       │   └── webserver.conf
│       └── usr
│           ├── bin
│           │   └── ddnsrun -> /usr/sbin/ddns/ddnsrun.3322
│           ├── etc
│           │   └── sensor.conf
│           └── lib
│               ├── libSensor.so -> /usr/lib/libsns_ov9712a.so
│               └── libonvif.so -> /usr/lib/libonvif_def.so
└── tree

17 directories, 98 files

```

modified `exclude.lst` to try and pull in the right functionality:

```
NOT_config_devs.ini
NOT_config_net.ini
NOT_config_priv.ini
NOT_wifi.ini
NOT_ifattr
NOT_ddns_tvs.conf
```

and restored it back to the device:

```
the ipcam will be restore. Are you sure?
```

no new functionality was exposed via nmap and still couldn't log in over telnet, but a second backup confirmed that my 'settings' were restored correctly. time to find another avenue.

`/mnt/config/ipcamera/network/wifi.conf` contains the current WiFI SSID/password:
```
wifienable="1"
wifiessid=TEST-WIFI
wifikeytype=3
wifiwhichkey=0
wifikey="TEST-WIFI"
```

`/mnt/config/ipcamera/config_server.ini` looks has an interesting block:
```ini
;
;[mctp]
;port                           = 8001
;
;[devs]
;port                           = 8002
;
;[es]
;port                           = 8003
;
```

`/mnt/config/ipcamera/config_mtmng.ini` appears to be what we're looking for:
```ini
[rtspsvr]
enable			       = 1
lisnport                       = 554
max_conn_num		       = 32
udp_sendport_min               = 5000
udp_sendport_min               = 6000
com_id                         = 012345678901234567890123

[httpsvr]
enable			       = 1
lisnport                       = 8800
max_conn_num		       = 32
...
[owspsvr]
enable                         = 1
max_conn_num                   = 4
server_ipaddr              = "192.168.1.18"
server_port                = 15960
username                   = "admin"
password                   = "admin"
quality                    = 1              ;0:32K,1:64K,2:128K,3:512K
companyIdentity            = "LT4a7a46c5571ce"
...
[langtaodev]
server_ipaddr              = "61.139.77.71"
server_port                = 15961
username                   = "ip700"
password                   = "00"
deviceid                   = 1929
versionMajor               = 2
versionMinor               = 1
mediaType                  = 1              ;1:VIDEO,2;VIDEO & AUDIO
devideModule               = 2            ; 1:MODULE_MASTER, 2:MODULE_PARSVE
chnId                      = 11             ;chnID: 011

[langtaodev-scdx1]
server_ipaddr              = "61.139.77.71"
server_port                = 15961
username                   = "ip700"
password                   = "00"
deviceid                   = 1929
versionMajor               = 2
versionMinor               = 1
mediaType                  = 1              ;1:VIDEO,2;VIDEO & AUDIO
devideModule               = 2            ; 1:MODULE_MASTER, 2:MODULE_PARSVE
chnId                      = 11             ;chnID: 011
```

that last part is a bit concerning - whois `61.139.77.71`?

```
$ host 61.139.77.71
Host 71.77.139.61.in-addr.arpa. not found: 3(NXDOMAIN)
$ ping -c 3 61.139.77.71
PING 61.139.77.71 (61.139.77.71): 56 data bytes
Request timeout for icmp_seq 0
Request timeout for icmp_seq 1
Request timeout for icmp_seq 2
--- 61.139.77.71 ping statistics ---
3 packets transmitted, 0 packets received, 100.0% packet loss
```

`/mnt/config/ipcamera/config_log.ini` shows that syslog is disabled:
```ini
lenmsg                         = "512        	";Ӧ���������ĳ���
syslog                         = "n             " ;�Ƿ����ϵͳ��־
savefile                       = "y             " ;�Ƿ���ļ�;
filename                       = "/bin/vs/log/debuglog.txt  ";
filemaxsize                    = "500            ";����ļ����������,��KBΪ��λ

```

enabling it blindly, but also looking for a way to get the file on disk

after a few modifications:

```
 nmap 192.168.42.24 -PN -sV -p 1-65535

Starting Nmap 6.46 ( http://nmap.org ) at 2016-07-16 13:53 PDT
Nmap scan report for 192.168.42.24
Host is up (0.0085s latency).
Not shown: 65528 closed ports
PORT      STATE SERVICE VERSION
23/tcp    open  telnet  Busybox telnetd
80/tcp    open  http    thttpd 2.25b 29dec2003
554/tcp   open  rtsp?
1018/tcp  open  soap    gSOAP soap 2.8
1235/tcp  open  unknown
8840/tcp  open  unknown
41477/tcp open  unknown

```

### nmap
```
Starting Nmap 6.46 ( http://nmap.org ) at 2016-07-16 10:46 PDT
Nmap scan report for 192.168.42.24
Host is up (0.0100s latency).
Not shown: 997 closed ports
PORT    STATE SERVICE VERSION
23/tcp  open  telnet  Busybox telnetd
80/tcp  open  http    thttpd 2.25b 29dec2003
554/tcp open  rtsp?
```

nmap was able to get traffic back from `554`, but it was an unrecognized fingerprint:

```
SF-Port554-TCP:V=6.46%I=7%D=7/16%Time=578A72F1%P=x86_64-apple-darwin13.1.0
SF:%r(GetRequest,4E,"RTSP/1\.0\x20400\x20Bad\x20Request\r\nCache-Control:\
SF:x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(RTSPRequest,6F
SF:,"RTSP/1\.0\x20200\x20OK\r\nServer:\x20HiIpcam/V100R003\x20VodServer/1\
SF:.0\.0\r\nPublic:\x20OPTIONS,\x20DESCRIBE,\x20SETUP,\x20TEARDOWN,\x20PLA
SF:Y\r\n\r\n")%r(GenericLines,4E,"RTSP/1\.0\x20400\x20Bad\x20Request\r\nCa
SF:che-Control:\x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(H
SF:TTPOptions,6F,"RTSP/1\.0\x20200\x20OK\r\nServer:\x20HiIpcam/V100R003\x2
SF:0VodServer/1\.0\.0\r\nPublic:\x20OPTIONS,\x20DESCRIBE,\x20SETUP,\x20TEA
SF:RDOWN,\x20PLAY\r\n\r\n")%r(RPCCheck,4E,"RTSP/1\.0\x20400\x20Bad\x20Requ
SF:est\r\nCache-Control:\x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\
SF:r\n")%r(DNSVersionBindReq,4E,"RTSP/1\.0\x20400\x20Bad\x20Request\r\nCac
SF:he-Control:\x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(DN
SF:SStatusRequest,4E,"RTSP/1\.0\x20400\x20Bad\x20Request\r\nCache-Control:
SF:\x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(Help,4E,"RTSP
SF:/1\.0\x20400\x20Bad\x20Request\r\nCache-Control:\x20no-cache\r\nServer:
SF:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(SSLSessionReq,4E,"RTSP/1\.0\x20400\x
SF:20Bad\x20Request\r\nCache-Control:\x20no-cache\r\nServer:\x20Hisilicon\
SF:x20Ipcam\r\n\r\n")%r(Kerberos,4E,"RTSP/1\.0\x20400\x20Bad\x20Request\r\
SF:nCache-Control:\x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\r\n")%
SF:r(SMBProgNeg,4E,"RTSP/1\.0\x20400\x20Bad\x20Request\r\nCache-Control:\x
SF:20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(X11Probe,4E,"RT
SF:SP/1\.0\x20400\x20Bad\x20Request\r\nCache-Control:\x20no-cache\r\nServe
SF:r:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(FourOhFourRequest,4E,"RTSP/1\.0\x2
SF:0400\x20Bad\x20Request\r\nCache-Control:\x20no-cache\r\nServer:\x20Hisi
SF:licon\x20Ipcam\r\n\r\n")%r(LPDString,4E,"RTSP/1\.0\x20400\x20Bad\x20Req
SF:uest\r\nCache-Control:\x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n
SF:\r\n")%r(LDAPBindReq,4E,"RTSP/1\.0\x20400\x20Bad\x20Request\r\nCache-Co
SF:ntrol:\x20no-cache\r\nServer:\x20Hisilicon\x20Ipcam\r\n\r\n")%r(SIPOpti
SF:ons,79,"RTSP/1\.0\x20200\x20OK\r\nServer:\x20HiIpcam/V100R003\x20VodSer
SF:ver/1\.0\.0\r\nCseq:\x2042\r\nPublic:\x20OPTIONS,\x20DESCRIBE,\x20SETUP
SF:,\x20TEARDOWN,\x20PLAY\r\n\r\n");
Service Info: Host: RT-IPC
```

scanning harder, we see:

```
nmap 192.168.42.24 -PN -sV -p 1-65535

Starting Nmap 6.46 ( http://nmap.org ) at 2016-07-16 13:33 PDT
Nmap scan report for 192.168.42.24
Host is up (0.011s latency).
Not shown: 65528 closed ports
PORT      STATE SERVICE VERSION
23/tcp    open  telnet  Busybox telnetd
80/tcp    open  http    thttpd 2.25b 29dec2003
554/tcp   open  rtsp?
1018/tcp  open  soap    gSOAP soap 2.8
1235/tcp  open  unknown
8840/tcp  open  unknown
47056/tcp open  unknown
```

```
 nmap 192.168.42.24 -PN -sV -p 1-65535

Starting Nmap 6.46 ( http://nmap.org ) at 2016-07-16 13:53 PDT
Nmap scan report for 192.168.42.24
Host is up (0.0085s latency).
Not shown: 65528 closed ports
PORT      STATE SERVICE VERSION
23/tcp    open  telnet  Busybox telnetd
80/tcp    open  http    thttpd 2.25b 29dec2003
554/tcp   open  rtsp?
1018/tcp  open  soap    gSOAP soap 2.8
1235/tcp  open  unknown
8840/tcp  open  unknown
41477/tcp open  unknown
```

looking at packet captures, we see:

```
GET /cgi-bin/hi3510/checkuser.cgi?&-name=admin&-passwd=admin&-time=1468691201459 HTTP/1.1
Host: 192.168.42.24
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:47.0) Gecko/20100101 Firefox/47.0
Accept: */*
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
X-Requested-With: XMLHttpRequest
Referer: http://192.168.42.24/web/index.html
Connection: keep-alive

HTTP/1.0 200 OK
Content-Type:text/html

var check="1";
 var authLevel ="255";
```

indicating a successful login, which sets a cookie:
```
Cookie: language=en; username=YWRtaW4%3D; password=YWRtaW4%3D; authLevel=255
```

so 8 characters, final being `=`, likely padding giving us `YWRtaW4=`. a quick base64 decode shows that we're effectively passing passwords in the clear:

```
$ echo YWRtaW4= | base64 -dD
Jul 16 14:15:32 mba base64[75917] <Info>: Read 9 bytes.
Jul 16 14:15:32 mba base64[75917] <Info>: Decoded to 5 bytes.
Jul 16 14:15:32 mba base64[75917] <Info>: Wrote 5 bytes.
admin
```

```
POST /web/cgi-bin/hi3510/param.cgi HTTP/1.1
Host: 192.168.42.24
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:47.0) Gecko/20100101 Firefox/47.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://192.168.42.24/web/user.html
Cookie: language=en; username=YWRtaW4%3D; password=YWRtaW4%3D; authLevel=255
Connection: keep-alive
Content-Type: application/x-www-form-urlencoded
Content-Length: 283

cmd=updateuser&cururl=http%3A%2F%2F192.168.42.24%2Fweb%2Fuser.html&user0=admin%3Aadmin%3A255%3AAdmin&user1=guest%3Aguest%3A3%3AGuest&user2=root%3Afoobarbaz%3A3%3ANormal&user3=%3A%3A3%3ANormal&user4=%3A%3A3%3ANormal&user5=%3A%3A3%3ANormal&user6=%3A%3A3%3ANormal&user7=%3A%3A3%3ANormal
```

```
GET /tmpfs/config_backup.bin HTTP/1.1
Host: 192.168.42.24
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:47.0) Gecko/20100101 Firefox/47.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://192.168.42.24/web/initializemain.html
Connection: keep-alive

HTTP/1.1 200 OK
Server: thttpd/2.25b 29dec2003
Content-Type: application/octet-stream
Date: Sat, 16 Jul 2016 18:03:12 GMT
Last-Modified: Sat, 16 Jul 2016 18:03:12 GMT
Accept-Ranges: bytes
Connection: close
Content-Length: 25098
```

getting the backup file from the web UI doesn't require/pass a cookie at all

```
GET /cgi-bin/hi3510/ptzleft.cgi?&-chn=0&-speed=31&-randoma8b9ctime=%221468693040013%22 HTTP/1.1
Host: 192.168.42.24
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:47.0) Gecko/20100101 Firefox/47.0
Accept: */*
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
X-Requested-With: XMLHttpRequest
Referer: http://192.168.42.24/web/index.html
Connection: keep-alive

HTTP/1.0 200 OK
Content-Type:text/html

call ptz funtion success

```

amusing typo in an API method:

```
GET /web/cgi-bin/hi3510/param.cgi?cmd=getsdcareInfo HTTP/1.1
Host: 192.168.234.1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:46.0) Gecko/20100101 Firefox/46.0
Accept: */*
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://192.168.234.1/web/storage.html
Cookie: language=en; auto login=0; username=YWRtaW4%3D; password=YWRtaW4%3D; authLevel=255
Connection: keep-alive
Pragma: no-cache
Cache-Control: no-cache

HTTP/1.0 200 OK
Content-Type:text/html

sdstatus="out";
sdfreespace="0 ";
sdtotalspace="0 ";
```

more non-cookie based requests, this time for wireless network scanning:
```
GET /cgi-bin/scanwifi.cgi?cmd=scanwifi.cgi&-time=%221465316774370%22 HTTP/1.1
Host: 192.168.234.1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:46.0) Gecko/20100101 Firefox/46.0
Accept: text/plain, */*; q=0.01
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
X-Requested-With: XMLHttpRequest
Referer: http://192.168.234.1/web/wifi.html
Connection: keep-alive

HTTP/1.0 200 OK
Content-Type:text/plain


var ssid_1="bssid signal ssid";
var ssid_2="Sonic.net-972";
var ssid_3="Artein";
var ssid_4="Sonic-4443";
var ssid_5="sinL";
var ssid_6="Harrison Jones";
var ssid_7="";
var ssid_8="BiscuitHammer";
var ssid_9="NETGEAR56";
var ssid_10="NETGEAR52";
var ssid_11="House LANnister";
var ssid_12="elma";
var ssid_13="Purplepashmina";
var ssid_14="";
var ssid_15="Registry-2";
var ssid_16="KAM_Francisco_2G";
var ssid_17="bluthcompanyHQ";
var ssid_18="bluthcompanyGUEST";
var ssid_19="folsom942";
var ssid_20="PRIVATENETWORK";
var ssid_21="legofeel";
var ssid_22="Temple of Joseidon";
var ssid_23="xfinitywifi";
var ssid_24="MonkeyBrains.net";
var ssid_25="APZ-Guest";
var ssid_26="imaqtpie";
var ssid_27="citicomm";
var ssid_28="APZ";
var ssid_29="711";
var ssid_30="macchiato";
var ssid_31="Winternet is coming";
var ssid_32="Pretty fly for a Wifi";
var ssid_33="MU Guest";
var ssid_34="Jeff's Wi-Fi Network";
var ssid_35="";
var ssid_36="CYWD";
var ssid_37="HouseofEghbali";
var ssid_38="xfinitywifi";
var ssid_39="HP-Print-D7-ENVY 4500 series";
var ssid_40="TP-LINK_38BC";
var ssid_41="";
var ssid_42="seattlestyle";
var ssid_43="Celsus932";
var ssid_44="";
var ssid_45="";
var ssid_46="OwnYourData2.4";
var ssid_47="CGN3-78F8";
var ssid_48="Bespoke";
var ssid_49="ATT448";
var ssid_50="";
var ssid_51="";
var ssid_52="HP-Print-29-Officejet Pro 8600";
var ssid_53="YBL540 Office";
var ssid_54="Kelefant";
var ssid_55="SKNet";
var ssid_56="HOME-4688";
var ssid_57="ATT504";
var ssid_58="ATT3D637f3";
var ssid_59="ATT336";
var ssid_60="";
var ssid_61="xfinitywifi";
var ssid_62="xfinitywifi";
var ssid_63="jaljeera";
var ssid_64="DNG24";
var ssid_65="happy";
var ssid_66="xfinitywifi";
var signal_1="bssid";
var signal_2="255";
var signal_3="239";
var signal_4="229";
var signal_5="229";
var signal_6="198";
var signal_7="198";
var signal_8="188";
var signal_9="178";
var signal_10="168";
var signal_11="168";
var signal_12="168";
var signal_13="168";
var signal_14="168";
var signal_15="158";
var signal_16="158";
var signal_17="158";
var signal_18="158";
var signal_19="147";
var signal_20="147";
var signal_21="147";
var signal_22="147";
var signal_23="147";
var signal_24="147";
var signal_25="147";
var signal_26="137";
var signal_27="137";
var signal_28="137";
var signal_29="137";
var signal_30="137";
var signal_31="137";
var signal_32="137";
var signal_33="137";
var signal_34="137";
var signal_35="137";
var signal_36="137";
var signal_37="137";
var signal_38="137";
var signal_39="137";
var signal_40="127";
var signal_41="127";
var signal_42="127";
var signal_43="127";
var signal_44="127";
var signal_45="127";
var signal_46="127";
var signal_47="127";
var signal_48="127";
var signal_49="127";
var signal_50="127";
var signal_51="127";
var signal_52="127";
var signal_53="117";
var signal_54="117";
var signal_55="117";
var signal_56="117";
var signal_57="117";
var signal_58="117";
var signal_59="117";
var signal_60="117";
var signal_61="117";
var signal_62="117";
var signal_63="107";
var signal_64="107";
var signal_65="107";
var signal_66="107";
var secret_1="bssid";
var secret_2="[WPA2-PSK-CCMP][ESS]";
var secret_3="[WPA2-PSK-CCMP][ESS]";
var secret_4="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_5="[WPA2-PSK-CCMP][ESS]";
var secret_6="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_7="[WEP][ESS]";
var secret_8="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_9="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_10="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_11="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_12="[WPA2-PSK-CCMP][ESS]";
var secret_13="[WPA2-PSK-CCMP][ESS]";
var secret_14="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_15="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_16="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_17="[WPA2-PSK-CCMP][ESS]";
var secret_18="[WPA2-PSK-CCMP][ESS]";
var secret_19="[WPS][WEP][ESS]";
var secret_20="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_21="[WPA2-PSK-CCMP][ESS]";
var secret_22="[WPA-PSK-CCMP][WPA2-PSK-CCMP][WPS][ESS]";
var secret_23="[ESS]";
var secret_24="[ESS]";
var secret_25="[ESS]";
var secret_26="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_27="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_28="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_29="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_30="[WPA2-PSK-CCMP][ESS]";
var secret_31="[WPA2-PSK-CCMP][ESS]";
var secret_32="[WPA2-PSK-CCMP][ESS]";
var secret_33="[WPA2-PSK-CCMP][ESS]";
var secret_34="[WPA2-PSK-CCMP][ESS]";
var secret_35="[WPA2-PSK-CCMP][ESS]";
var secret_36="[WPA2-PSK-CCMP+TKIP][ESS]";
var secret_37="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][WPS][ESS]";
var secret_38="[ESS]";
var secret_39="[ESS]";
var secret_40="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_41="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_42="[WPA2-PSK-CCMP][ESS]";
var secret_43="[WPA2-PSK-CCMP][ESS]";
var secret_44="[WPA2-PSK-CCMP][ESS]";
var secret_45="[WPA2-PSK-CCMP][ESS]";
var secret_46="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][WPS][ESS]";
var secret_47="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_48="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_49="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_50="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_51="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_52="[ESS]";
var secret_53="[WPA2-PSK-CCMP][ESS]";
var secret_54="[WPA2-PSK-CCMP][ESS]";
var secret_55="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][WPS][ESS]";
var secret_56="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][WPS][ESS]";
var secret_57="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_58="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_59="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_60="[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]";
var secret_61="[ESS]";
var secret_62="[ESS]";
var secret_63="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_64="[WPA2-PSK-CCMP][WPS][ESS]";
var secret_65="[WPA2-PSK-CCMP][ESS]";
var secret_66="[ESS]";
```