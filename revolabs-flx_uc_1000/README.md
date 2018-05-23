# revolabs flx UC1000

found this device in a conference room, found the IP from an unauthenticated menu on the dialer, which was accessible from the wireless 'Guest' network. it also has USB ports, so potentially available without network access.

## story time

from the page that loaded when you first hit `http://<device>`, noticed `app.js` was being loaded.

in it, i found:
```json
 sys.password:
  - defaultVal: "7386",
  - pattern: /^(\d{4,})$/,
```

so we can assume that there are only 9999 possibilities, which is definitely small enough to brute force.

there doesn't seem to be any protection/rate limiting - other than the CPU, so.. [bf_login.rb](bf_login.rb)

## tools
name | description
-----|-------------
[bf_login.rb](bf_login.rb) | brute forces the PIN on the web interface
[generate_contacts.rb](generate_contacts.rb) | generates potentially malicious contact files to be uploaded

### bf_login.rb

key      | value
---------|------
single   | `./bf_login.rb 192.168.1.1`
range    | `./bf_login.rb 192.168.1.*`, will hit 1..254

attempts to connect to an HTTP endpoint, and then attempts to auth until the PIN is found:
  * valid range is `0000` to `9999`
  * since possibly set by humans, prioritize progressive/related/repeating combinations

found PINs are output to a SQLite3 database, `bflogin.db`, and if scanning a host where PIN is already known, they immediately return.

### generate_contacts.rb

key   | value
------|------
usage | `./generate_contacts.rb`

builds potentially (as in untested) malicious contact files, attempting to exploit:

  * too many contacts, currently 100k (2.9mb) (`contacts-huge.csv`)
  * duplicate name/phone/ID contacts (`contacts-duplicates.csv`)

more testing and expansion to come.

## functionality exposed via web interface
  * change settings
    * screen brightness, timeout, enable/disable
    * LED colors, enable/disable
    * SIP settings
    * DHCP, NTP settings
    * name displayed
    * etc
  * upgrade firmware - need to do more digging here
  * restart device
  * pull logs/configuration
    * SIP password is not included in exported config.xml

the same functionality, in a different interface is now available on the dialer as well as via HTTP. interestingly, many features/settings are exposed on the dialer, while all access over HTTP must be authenticated

## further research

### SIP password exposed

the SIP password is notably absent from configuration exports, and masked in the browser, but there are 2 avenues to recovering it anyway:
  * once the PIN is known, viewing 'Options'->'SIP settings' from the physical device exposes the plaintext password
  * the PIN is masked in the web interface, but only because the <input type='password'>, and since the traffic is running over HTTP, sniffing web traffic while the page is loaded exposes the plaintext password

in a twist on the second issue mentioned above, if any other changes are made on the 'SIP Settings' page (like the display name), when 'Submit' is clicked, your browser will prompt you to save the password. standard saved password recovery tools will expose the plaintext password too

### firmware digging

from Settings-> functionality, `ps.txt` confirmed that the machine is running a small Linux distribution.
a quick check of the manufacturers website gave us a copy of the latest firmware [2.6.0.294](https://www.revolabs.com/getmedia/1569b057-96f3-44e0-a521-e1bdeef21831/FLX-UC-1000-1500-Firmware)

`binwalk`ing the uncompressed file:

```
$ binwalk FLX-UC-1500-2-6-0-294.bundle

DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------
138364        0x21C7C         CRC32 polynomial table, little endian
266272        0x41020         uImage header, header size: 64 bytes, header CRC: 0x4A150CD3, created: 2016-03-11 22:03:35, image size: 1338940 bytes, Data Address: 0xC0008000, Entry Point: 0xC0008000, data CRC: 0x793D4693, OS: Linux, CPU: ARM, image type: OS Kernel Image, compression type: none, image name: "Linux-2.6.37+"
283460        0x45344         gzip compressed data, maximum compression, from Unix, last modified: 2016-03-11 22:03:34
1708064       0x1A1020        Squashfs filesystem, little endian, version 4.0, compression:gzip, size: 17871508 bytes, 1007 inodes, blocksize: 131072 bytes, created: 2016-03-11 22:17:40
19642065      0x12BB6D1       Zlib compressed data, best compression
```

of particular interest to us is `0x1A1020        Squashfs filesystem..`:

```
# mkdir /squash/
# mount -o loop -t squashfs /tmp/1A1020 /squash/
# ls /squash/
bin  dev  etc  home  lib  linuxrc  mnt  nv  opt  proc  root  run  sbin  sys  tmp  usr  var  www
```

digging around, there are a number of interesting files:

file                  | description
----------------------|-------------
`/etc/passwd`         | list of users
`/etc/shadow`         | hashes of users passwords
`/etc/init.d/S45Revo` | init script for the Revo application
`/usr/sbin/telnetd`   | telnet server binary

20 minutes on a modestly provisioned GCP instance with john yields the passwords:

user       | password
-----------|---------
`default`  | `<redacted*>`
`revolabs` | `<redacted*>`
`root`     | `<redacted*>`

* have not reported any issues documented here to Revo Labs, exercise is left to the reader.

looking at the `S45Revo` file, a potential avenue to `uid=0`:

```
14  # restmgr will start telnetd if telnet_enabled uboot env does not exist or is set to 1
15  restmgr &
```

more to come.

```
$ tree /squash/
...
│   └── modules
│       └── 2.6.37+
│           ├── build -> /home/hudson/jobs/Ruby1000-Tools/workspace/Ruby/dvsdk/psp/linux-2.6.37-psp03.21.00.04.sdk
│           ├── kernel
│           │   └── drivers
│           │       ├── dsp
│           │       │   └── dsplinkk.ko
│           │       └── usb
│           │           ├── core
│           │           │   └── usbcore.ko
│           │           ├── musb
│           │           │   ├── da8xx.ko
│           │           │   └── musb_hdrc.ko
│           │           ├── otg
│           │           │   └── nop-usb-xceiv.ko
│           │           └── serial
│           │               └── usbserial.ko
...
```

well at least they're using CI..


```
│   ├── USB_Digital_Audio1500_bb.cyacd
│   ├── USB_Digital_Audio1500.cyacd
│   ├── USB_Digital_Audio_bb.cyacd
│   ├── USB_Digital_Audio.cyacd
```

according to [a quick google search](http://www.cypress.com/knowledge-base-article/format-cyacd-file-psoc-3-or-psoc-5lp-bootloader-kba216138), these are 'Code Data Files' for the PSoC 3 or PSoC 5 Bootloader

with a format of:
```
[1-byte ArrayID][2-byte RowNumber][2-byte DataLength][N-byte Data][1byte Checksum]
```

```
# head /squashy/sbin/USB_Digital_Audio1500_bb.cyacd
1E07D0690301
:0000280120022EE9008F828E83E0540100000070F82278FFE4F6D8FD022F18BB010689828A83E0225002E722BBFE02E32289828A83E49322BB010689828A83F0225002F722BBFE01F322C5F0F8A3E028F0C5F0F8E582158270021583E038F022A3F8E0C5F025F0F0E582158270021583E0C838F0E822BB010A89828A83E0F5F0A3E022500687F009E71922BBFE07E3F5F009E3192289828A83E493F5F074019322BB010A89828A83F0E5F0A3F0225006F70
9A7F01922BBFE06F3E5F009F31922EF2BFFEE3AFEED39FDEC38FC22C3EF9BFFEE9AFEED99FDEC98FC22E88FF0A4CC8BF0A42CFCE98EF0A42CFC8AF0EDA42CFCEA8EF0A4CDA8F08BF0A42DCC3825F0FDE98FF0A4250045017E0
20052040404104011C07C4000640527048203837F84078A7F0100A3
:00002901202CCD35F0FCEB8EF0A4FEA9F0EB8FF0A4CFC5F02ECD39FEE43CFCEAA42DCE35F0FDE43CFC2275F008758200EF2FFFEE33FECD33CDCC33CCC58233C5829BED9AEC99E58298400CF582EE9BFEED9AFDEC99FC0FD5F0D6E4CEFBE4CDFAE4CCF9A88222B800C1B90059BA002DEC8BF084CFCECDFCE5F0CBF97818EF2FFFEE33FEED33FDEC33FCEB33FB10D703994004EB99FB0FD8E5E4F9FA227818EF2FFFEE33FEED33FDEC33FCC933C910D7059BE
99A4007EC9BFCE99AF90FD8E0E4C9FAE4CCFB2275F010EF2FFFEE33FEED33FDCC33CCC833C810D7079BEC9AE899400AED9BFDEC9AFCE899F80FD5F0DAE4CDFBE4CCFAE4C8F922EF5BFFEE5AFEED59FDEC58FC225A0304040F0
81109020A220B0D0C070E081480150616701709188019011A701C0B
```


```
...
    │   └── udev
    │       ├── saved.cmdline
...
```

shows us that they are booting with ```mem=128M console=ttyS0,115200n8 root=/dev/ram0 rw initrd=0xc1180000,4m ip=off```, which should help with the TFTP booting attack

```js
.call(this), function () {
    "use strict";
    angular.module("r1kApp").config(["$stateProvider", function (a) {
        return a.state("main.diag", {url: "diag", templateUrl: "app/diag/diag.html", controller: "DiagCtrl"})
    }]), angular.module("r1kApp").controller("DiagCtrl", ["$scope", "Device", "$rootScope", function (a, b) {
        return a.forms = diag.forms, a.diag = [], a.submitForm = function (c) {
            var d;
            return d = {}, d[c] = a.diag[c] || "", b.request("RequestStatus", d).then(function () {
                return a.buildToast("Command has been sent.")
            }, function () {
                return a.buildToast("Uh oh! Couldn't send command. Is the device available?")
            })
        }
    }])
```

looking at this, it would appear that http://<device>/app/diag/diag.html exposes a mechanism to execute arbitrary commands. `/usr/sbin/telnetd` anyone?

### log mining and traffic sniffing

using <dump logs?> functionality, and the high logging levels they provided, was able to determine a number of things:

  * it utilizes the [pjsua](http://www.pjsip.org/pjsua.htm) library/client
  * it sends a TFTP BOOT request for tftp://<primary SIP registrar>/<static hex string>.xml every 30 seconds

next step will be combining the information about the `telnet_enabled` kernel parameter, and crafting a TFTP configuration that will do just that.
