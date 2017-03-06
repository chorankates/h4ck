# mfi

- [device](#device)
- [digging](#digging)
  - [nmap](#nmap)
  - [sniffing](#sniffing)
  - [filesystem](#filesystem)
- [firmware](#firmware)

## device
name            | value
----------------|-----
model           | `mPower mFi 3-port Power Wifi`
firmware        | `2.0.8`
features        | `BusyBox`
vulnerabilities | HTTP plain text authentication, easily guessable root password, telnet/ssh services running by default

## digging

### nmap

from `nmap -PN -p 1-65535 172.16.42.233`, we get:

```
Starting Nmap 5.21 ( http://nmap.org ) at 2017-02-19 15:04 PST
Nmap scan report for mFi.lan (172.16.42.233)
Host is up (0.060s latency).
Not shown: 961 closed ports, 32 filtered ports
PORT      STATE SERVICE    VERSION
22/tcp    open  ssh        Dropbear sshd 0.51 (protocol 2.0)
23/tcp    open  telnet     Linksys WRT54G telnetd (Tomato firmware)
53/tcp    open  tcpwrapped
80/tcp    open  http       lighttpd 1.4.31
443/tcp   open  ssl/http   lighttpd 1.4.31
8080/tcp  open  http       lighttpd 1.4.31
49152/tcp open  upnp       Portable SDK for UPnP devices 1.6.18 (kernel 2.6.32.29; UPnP 1.0)
Service Info: OS: Linux; Device: WAP
```

ssh and telnet?
3 different lighttpd endpoints?

### sniffing

after finally completing the initial configuration and getting the device on my network, i was presented with a username/password prompt. there was no indication about what realm the authentication was going against, and none of the configured passwords worked.

a quick google search indicated that the default username/password was `ubnt` / `ubnt` - this was not included in the manual.

watching the packets:

```
POST /login.cgi HTTP/1.1
Host: 172.16.42.233
Connection: keep-alive
Cache-Control: max-age=0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
Accept-Encoding: gzip, deflate, sdch
Accept-Language: en-US,en;q=0.8

------WebKitFormBoundaryLR15GqkcNTCm9LZP
Content-Disposition: form-data; name="uri"

/
------WebKitFormBoundaryLR15GqkcNTCm9LZP
Content-Disposition: form-data; name="username"

ubnt
------WebKitFormBoundaryLR15GqkcNTCm9LZP
Content-Disposition: form-data; name="password"

ubnt
------WebKitFormBoundaryLR15GqkcNTCm9LZP
Content-Disposition: form-data; name="Submit"

Login
------WebKitFormBoundaryLR15GqkcNTCm9LZP--

HTTP/1.1 302 Found
Location: /
Set-cookie: ui_language=en_US; expires=Tuesday, 19-Jan-38 03:14:07 GMT
Content-type: text/html
Transfer-Encoding: chunked
Date: Thu, 01 Jan 1970 00:44:18 GMT
Server: lighttpd/1.4.31

0
```

yep, passing credentials in the clear, not even usig HTTP BasicAuth.

once we're authenticated, calls to `/mfi/sensors.cgi?t=<0.nnn>` started returning JSON:

```
GET /mfi/sensors.cgi?t=0.48375444280878943 HTTP/1.1
Host: 172.16.42.233
Connection: keep-alive
Accept: */*
X-Requested-With: XMLHttpRequest
Referer: http://172.16.42.233/power
Accept-Encoding: gzip, deflate, sdch
Accept-Language: en-US,en;q=0.8
Cookie: AIROS_SESSIONID=<redacted>>; ui_language=en_US

HTTP/1.1 200 OK
Expires: Sun, 01 Jan 1984 08:00:00 GMT
Cache-Control: must-revalidate
Content-type: application/json
Transfer-Encoding: chunked
Date: Thu, 01 Jan 1970 00:44:26 GMT
Server: lighttpd/1.4.31

1b2
{
    "sensors": [{
        "port": 1,
        "output": 1,
        "power": 0.0,
        "energy": 0.0,
        "enabled": 0,
        "current": 0.0,
        "voltage": 121.904592752,
        "powerfactor": 0.0,
        "relay": 1,
        "lock": 0
    }, {
        "port": 2,
        "output": 1,
        "power": 0.0,
        "energy": 0.0,
        "enabled": 0,
        "current": 0.0,
        "voltage": 122.275886535,
        "powerfactor": 0.0,
        "relay": 1,
        "lock": 0
    }, {
        "port": 3,
        "output": 1,
        "power": 0.0,
        "energy": 0.0,
        "enabled": 0,
        "current": 0.0,
        "voltage": 122.129747152,
        "powerfactor": 0.0,
        "relay": 1,
        "lock": 0
    }],
    "status": "success"
}0
```

### filesystem

there's no way they use the same password for the web interface that they do for telnet/ssh:

```
$ telnet 172.16.42.233
Trying 172.16.42.233...
Connected to mfi.lan.
Escape character is '^]'.
mFid64ce7 login: ubnt
Password:


BusyBox v1.11.2 (2013-11-11 20:08:57 PST) built-in shell (ash)
Enter 'help' for a list of built-in commands.

MF.v2.0.8#
```

oh. they do. and it's a root shell.

```
MF.v2.0.8# cat /etc/passwd
ubnt:KQiBBQ7dx8sx2:0:0:Administrator:/etc/persistent:/bin/sh
```

no `/etc/shadow`, but since the hash is present, 10 minutes on a GCP instance confirmed what we already knew.

```
MF.v2.0.8# cat cfg/mgmt
mgmt.is_default=true
mgmt.cloud_name=foo
mgmt.cloud_pass=37b51d194a7513e45b56f6524f2d51f2
```

when getting the device on the network initially, the username/password `foo`/`bar` was used, and sure enough:

```
$ echo -n 'bar' | md5sum
37b51d194a7513e45b56f6524f2d51f2  -
```

not that big of a deal if you use a strong password, but at this point, you can rest assured that many MD5 hashes are known and only a google search away.

```
MF.v2.0.8# ps w
...
  428 ubnt      1140 S    /sbin/hotplug2 --persistent --set-rules-file /usr/etc/hotplug2.rules
  430 ubnt      1972 S <  /bin/watchdog -t 1 /dev/watchdog
 1070 ubnt      1940 S    /bin/dropbear -F -d /var/run/dropbear_dss_host_key -r /var/run/dropbear_rsa_host_key -p 22
 1072 ubnt      1976 S    /bin/syslogd -n -O /var/log/messages -l 8 -s 200 -b 0
 1074 ubnt      1288 S    /bin/dnsmasq -k -C /etc/dnsmasq.ath1.conf -x /var/run/dnsmasq.ath1.pid
 1077 ubnt      1988 S    /bin/telnetd -F -p 23
 1078 ubnt      1984 S    /bin/crond -f -S
11441 ubnt      1996 S    /sbin/udhcpc -f -i ath0 -V ubnt -A 10 -s /etc/udhcpc/udhcpc -p /var/run/udhcpc.ath0.pid -h mFi
13977 ubnt      6432 S    /bin/lighttpd -D -f /etc/lighttpd.conf
...
```

