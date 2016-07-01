# revolabs flx UC1000

found this device in a conference room, found the IP from an unauthenticated menu on the dialer, which was accessible from the wireless 'Guest' network. it also has USB ports, so potentially available without network access.

## story time

from the page that loaded when you first hit http://<device>, i noticed `app.js`

in it, i found:
```json
 sys.password:
  - defaultVal: "7386",
  - pattern: /^(\d{4,})$/,
```


## tools
name | description
-----|-------------
[bf_login.rb](bf_login.rb) | brute forces the PIN on the web interface