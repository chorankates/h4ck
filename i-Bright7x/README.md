# TriCascade i-Bright7x

- [device](#device)
- [digging](#digging)
  - [nmap](#nmap)
  - [jnlp](#jnlp)

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

```java
// from com/insnergy/wifi/applet/e.java

    public final void run() {
        try {
            if (b.a((CharSequence)this.a.a) || !RegexPattern.DEVICE_ID.isValid(this.a.a)) {
                throw new ApiException("Not a valid device ID : " + this.a.a);
            }
            DeviceAP deviceAP = DeviceAP.of(this.a.a);
            WiFiDeviceAPI.a(this.a.b, deviceAP.getSsid(this.a.a), deviceAP.getPassword(this.a.a));
            Thread.sleep(1000);
            WiFiDeviceAPI.b(this.a.b, WiFiDeviceAPI.d(this.a.b).trigger(), "");
            return;
        }
...
```

in a roundabout way, we're right: the MAC address is being pulled out of the device ID, which is `'TC060000' + $MAC_ADDRESS`, hence the `substring`

additionally, it looks like the signature for `a` is `($IP, $SSID, $PASSWORD)`

```java
// from com/insnergy/wifi/device/api/c.java

    public final Connect a(String object, String string, String string2, String string3) {
        String string4 = "Connect?ssid={0}&secmode={1}&encrypt={2}";
        MessageFormat messageFormat = new MessageFormat(string4);
        if (b.b((CharSequence)string3)) {
            messageFormat = new MessageFormat(string4 + "&conpass={3}");
        }
        object = this.a(messageFormat, new String[]{object, string, string2, string3});
        return (Connect)this.a((JSONObject)object, new Connect());
    }
```


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

this is the only reference to this address, have not dug to deeply


password: 97451790c9

key  | value
-----|-------
MAC  | `8C:C7:AA:02:97:48`
SSID | `B78CC7AA029748` // so.. 'B7' + $MAC
ID   | `TC0600008CC7AA029748` // so 'TC060000' + $MAC

8CC7AA029748 in decimal is 154789178677064
