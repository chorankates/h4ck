# revolabs flx UC1000

found this device in a conference room, found the IP from an unauthenticated menu on the dialer, which was accessible from the wireless 'Guest' network. it also has USB ports, so potentially available without network access.

## story time

from the page that loaded when you first hit `http://<device>`, i noticed `app.js` was being loaded.

in it, i found:
```json
 sys.password:
  - defaultVal: "7386",
  - pattern: /^(\d{4,})$/,
```

so we can assume that there are only 9999 possibilities, which is definitely small enough to brute force.

there doesn't seem to be any protection/rate limiting, so..

## tools
name | description
-----|-------------
[bf_login.rb](bf_login.rb) | brute forces the PIN on the web interface

## functionality exposed
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
