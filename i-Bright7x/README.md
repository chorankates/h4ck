# TriCascade i-Bright7x

- [device](#device)
- [digging](#digging)
  - [nmap](#nmap)
  - [jnlp](#jnlp)
  - [live ports](#live_ports)
    - [23](#23)
    - [80](#80)
    - [8080](#8080)

## device
name     | value
---------|-----
model    | i-Bright7x
firmware | unknown currently
features | WiFi capable remote controled power supply. that runs linux

## digging

### nmap

from `nmap -PN -sV -p 1-65535 192.168.17.1`, get:

```
PORT     STATE SERVICE VERSION
23/tcp   open  telnet  BusyBox telnetd
53/tcp   open  domain  dnsmasq 2.59rc1
80/tcp   open  http
8080/tcp open  http    GoAhead WebServer
```

the same service looks to be running on both `80` and `8080`, prompting for a username and password, but none are provided by the manufacturer.

it appears that the only way to configure this device is to use the Java applet through [bright.tricascade.com](https://bright.tricascade.com)

### jnlp

by watching traffic, see that the applet is served from [resources/applet/WifiDevice.jnlp](https://bright.tricascade.com/resources/applet/WiFiDeviceAPI.jnlp)

finding the corresponding `.jar` was more of a pain than expected, basically:

```
$ find ~/Library/Application Support/Oracle/Java/Deployment/cache/6.0 -type f -exec file {} \;
./10/78085f0a-4eab1a82: XML 1.0 document text, ASCII text, with CRLF, LF line terminators
./10/78085f0a-4eab1a82.idx: data
./10/78085f0a-c5a84a41ecc99150f548eb0393049f0d8c67849abe845af78c894a676aa18086-6.0.lap: ASCII text
./39/3dc5b4e7-2469db01-1.4.2-: Java archive data (JAR)
./39/3dc5b4e7-2469db01-1.4.2-.idx: data
./45/4766c42d-176a5aa0: XML 1.0 document text, ASCII text, with CRLF, LF line terminators
./45/4766c42d-176a5aa0.idx: data
./45/4766c42d-8bd095d4847349acdbba85a1e70f0d08d3990cfbb19c6007fde8f07bf0b52dbd-6.0.lap: ASCII text
./63/4600b2ff-0e27775cc2e9212bf6c7096ed895db16ef7cdd6b6f1d4e615eec8c92787d0f53-6.0.lap: ASCII text
./63/4d02c2bf-562ad327: Java archive data (JAR)
./63/4d02c2bf-562ad327.idx: data
...
$ 7z l 39/3dc5b4e7-2469db01-1.4.2-
Listing archive: ./39/3dc5b4e7-2469db01-1.4.2-

--
Path = ./39/3dc5b4e7-2469db01-1.4.2-
Type = zip
Physical Size = 77973

   Date      Time    Attr         Size   Compressed  Name
------------------- ----- ------------ ------------  ------------------------
2015-06-12 19:10:02 .....         8149         3263  META-INF/MANIFEST.MF
2015-06-12 19:10:04 .....         7954         3196  META-INF/BRIGHTEN.SF
2015-06-12 19:10:04 .....         6165         4081  META-INF/BRIGHTEN.RSA
2015-06-12 19:10:02 .....         2232          884  com/insnergy/wifi/applet/b.class
```

lucky guess.

unzipping gives a bit of a clue about the structure - but nothing really interesting.

[decompiling](decompile.sh) with the help of [cfr](http://www.benf.org/other/cfr/), however, does give us some hints:

```java
// from com/insnergy/wifi/value/DeviceAP.java

    public final String getSsid(String string) {
        return this.ssidPattern + DeviceAP.extractMac(string);
    }

    public static String extractMac(String string) {
        return string.substring(8, 20);
    }

    public final String getPassword(String string) {
        return a.a(DeviceAP.extractMac(string)).substring(0, 10).toLowerCase();
    }
```

it looks like the password is derived from the MAC address of the device - which is worse than it sounds, because the WiFi network it exposes for configuration is `'B7' + $MAC_ADDRESS`

walking the Java code backwards:
  * `DeviceAP.extractMac(string)` returns characters 8-20 of whatever it is passed
  * `a`, is called with the result of above, which initially was misunderstood since the decompilation was ambiguous
  * `substring(0, 10).toLowerCase()` is called on whatever `a` returns

within the context of what concrete values our device uses:

key      | value
---------|-------
MAC      | `8C:C7:AA:02:97:48`
SSID     | `B78CC7AA029748` // so.. 'B7' + $MAC - ':'
ID       | `TC0600008CC7AA029748` // so 'TC060000' + $MAC
password | `97451790c9`

8-20 characters fits as the actual MAC address inside the ID value, but that gives us '8cc7aa0297', not '97451790c9'

however, using the second-level deobfuscation feature of jadx turns `a` into `m56a`:
```java
// com/insnergy/wifi/p002b/C0020a.java

public static String m56a(String str) {
    try {
        if (C0021b.m61a((CharSequence) str)) {
            return "";
        }
        MessageDigest instance = MessageDigest.getInstance("MD5");
        instance.update(str.getBytes());
        return new HexBinaryAdapter().marshal(instance.digest());
    } catch (NoSuchAlgorithmException e) {
        e.toString();
        return "";
    }
}

```

giving us the final step we need:

```
$ echo -n 8CC7AA029748 | md5sum
97451790c91d3c78bee70be7bac5f9b0
$ echo 97451790c91d3c78bee70be7bac5f9b0 | cut -c1-10
97451790c9
```

the first 10 characters of the MD5 sum of the MAC address is the SSID password.

unfortunately, this password does not work when attempting to log in to the web application running on :80

## live ports

### 23

```
$ nc 192.168.17.1 23

BRIGHT7 login: admin
admin
Password: admin

Login incorrect
```

there is a 1-2 second delay before declaring the login incorrect, making bruteforce even less desirable than usual.

### 80

attempts to login leak validity of username and password independently.

when trying with `admin`, get redirected to `/index.htm?wrongpass1`:

```
$ curl http://192.168.17.1/cgi-bin/login.apply -v -d 'username=admin&password=password1234'
...
* Connected to 192.168.17.1 (192.168.17.1) port 80 (#0)
> POST /cgi-bin/login.apply HTTP/1.1
...
>
< HTTP/1.0 200 OK
< Content-Type: text/html
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="refresh" content="0;URL='/index.htm?wrongpass1'">
...
* Closing connection 0
```

and when trying with `user`, get redirected to `/index.htm?usernotfound`:
```
$  curl http://192.168.17.1/cgi-bin/login.apply -v -d 'usern
ame=user&password=user'
*   Trying 192.168.17.1...
* TCP_NODELAY set
* Connected to 192.168.17.1 (192.168.17.1) port 80 (#0)
> POST /cgi-bin/login.apply HTTP/1.1
> Host: 192.168.17.1
> User-Agent: curl/7.54.0
> Accept: */*
> Content-Length: 27
> Content-Type: application/x-www-form-urlencoded
>
* upload completely sent off: 27 out of 27 bytes
* HTTP 1.0, assume close after body
< HTTP/1.0 200 OK
< Content-Type: text/html
< Pragma: no-cache
< Cache-Control: no-cache,must-revalidate
< Expired: -9999
< Vary: *
<
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html
4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="refresh" content="0;URL='/index.htm?usernotfound'">
</head>
<body style="visibility:hidden;">
</body>
</html>
Set-Cookie: username=user;expire=-1;path=/
Set-Cookie: password=user;expire=-1;path=/
Set-Cookie: lang=en_US;expire=-1;path=/
Set-Cookie: cookieno=388505;expire=-1;path=/
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html
4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="refresh" content="0;URL='/dashboard_overview.html'">
</head>
<body style="visibility:hidden;">
</body>
</html>
```

but curiously, the `/dashboard_overview.html` route leaks. unfortunately it is just a mobile/desktop redirector:
```
$ curl http://192.168.17.1/dashboard_overview/
<!DOCTYPE html >
<html>
<head>
<title>Index</title>
<script type='text/javascript' src="jquery.js" > </script>
<script type='text/javascript' src="detectmobilebrowser.js" > </script>
<script type="text/javascript">
    $(document).ready(function() {
        if (!$.browser.mobile) {
            window.location.href = '/index.html';
        } else {
            window.location.href = '/mobile.html';
        }
    });
</script>
</head>
<body>
</body>
</html>
```

### 8080

```java
//
    protected a(String string, String string2) {
        String string3 = "http://192.168.17.1:8080/goform/";
        int n = 30000;
        if (com.insnergy.wifi.b.b.b((CharSequence)string)) {
            string3 = string;
        }
        if (com.insnergy.wifi.b.b.c(string2)) {
            n = Integer.parseInt(string2);
        }
        this.b = string3;
        this.c = n;
    }

```

this is the only reference to this address, and 'goform' doesn't lead to any obvious web frameworks or patterns

making recon difficult is the 'always 200' responses we see:

```
$ curl http://192.168.17.1:8080/goform/test
<html><head><title>Document Error:Data follows</title></head>
                <body><h2>Access Error:200 Data follows</h2>
                <p>Form test is not defined</p></body></html>
```

trying a few simple form names all proved to return the same response
