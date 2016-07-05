hoo2
====

i was initially interested in the HooToo TripMate Titan when someone on Twitter (thought it was @davepell, but can't find the tweet now) saying it was a great way to share battery/network/data from a single device.

that sounds cool - not just for the surface use cases: road trips, airplane flights, etc - but also because the features required meant the TripMate was a $39 low power, wifi enabled computer with it's own battery. <insert cheesy Zuckerberg misquote here>

my goal was always to gain access to this device in ways it's manufacturer hadn't intended, but what i found was a bit excessive.

some of the issues are as common as XSS vulnerabilities, others as serious as passing credentials/settings in plaintext over HTTP and a universally reused root password.

# devices
name|model|description|version|rooted?|services|vulnerabilities
----|-----|-----------|-------|-------|---------------
[TripMate Titan](http://www.hootoo.com/hootoo-tripmate-ht-tm05-wireless-router.html)|HT-TM05|NAS/WiFi bridge/battery| firmware: `2.000.022`|yes|`telnet`, `http (80, 81)`, `unknown 85, 8200)`|easily guessable default passwords, universal root password, credential exposure, data exposure, HTTP - variety
[TripMate](http://www.hootoo.com/hootoo-tripmate-ht-tm01-wireless-router.html)|HT-TM01|NAS/WiFi bridge/battery| firmware: `2.000.022`|yes|`telnet`, `http (80, 81)`|same as TripMate Titan
[TripMate Elite](http://www.hootoo.com/hootoo-tripmate-elite-ht-tm04-wireless-portable-router.html)|HT-TM06|NAS/WiFi bridge/battery/outlet|firmware: `2.000.004`|no|`http (80, 81)`|easily guessable default passwords, HTTP - variety
[TripMate Nano](http://www.hootoo.com/hootoo-tripmate-nano-ht-tm02-wireless-portable-router.html)|HT-TM02|NAS/WiFi bridge| firmware: `2.000.018`|yes|`telnet`, `http (80, 81)`, `unknown 85`|same as TripMate Titan

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
