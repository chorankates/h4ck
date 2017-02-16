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

## further research

### SIP password exposed

the SIP password is notably absent from configuration exports, and masked in the browser, but there are 2 avenues to recovering it anyway:
  * once the PIN is known, viewing 'Options'->'SIP settings' from the physical device exposes the plaintext password
  * the PIN is masked in the web interface, but only because the <input type='password'>, and since the traffic is running over HTTP, sniffing web traffic while the page is loaded exposes the plaintext password

in a twist on the second issue mentioned above, if any other changes are made on the 'SIP Settings' page (like the display name), when 'Submit' is clicked, your browser will prompt you to save the password. standard saved password recovery tools will expose the plaintext password too