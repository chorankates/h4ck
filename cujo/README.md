# CUJO

- [device](#device)
- [digging](#digging)
  - [nmap](#nmap)
  - [sniffing](#sniffing)
- [impersonating](#impersonating)
  - [phone home](#phone-home)

## device
name            | value
----------------|-----
model           | `TODO`
product         | `TODO`
firmware        | `TODO`
features        | TODO 
vulnerabilities | all phone-home calls are done over `HTTP`

## digging

### nmap

from `nmap -PN -p 1-65535 -sV <device>`, we get:

```
Nmap scan report for <device>
Host is up (0.0016s latency).
All 65535 scanned ports on <device> are closed

Nmap done: 1 IP address (1 host up) scanned in 321.80 seconds
```

so.. no open ports. let's try something different

### sniffing

watching the network activity of the device (`192.168.1.108`), noticed it tried to resolve:

  * `agent.cujo.io`
  * `jenkins.getcujo.com`
  
but since the network isn't allowing external traffic, the DNS resolution fails. 

the device continues to retry this, but takes no other action.

using `dnsmasq`, spoof these addresses to something under out control (`192.168.1.106`), and now we see:

```
Frame 125229: 74 bytes on wire (592 bits), 74 bytes captured (592 bits)
Ethernet II, Src: 192.168.1.108 (cc:d3:1e:d0:20:67), Dst: 192.168.1.106 (f4:0f:24:04:2e:8f)
Internet Protocol Version 4, Src: 192.168.1.108 (192.168.1.108), Dst: agent.cujo.io (192.168.1.106)
Transmission Control Protocol, Src Port: 53455 (53455), Dst Port: 9443 (9443), Seq: 0, Len: 0
    Source Port: 53455
    Destination Port: 9443
    [Stream index: 14]
    [TCP Segment Len: 0]
    Sequence number: 0    (relative sequence number)
    Acknowledgment number: 0
    Header Length: 40 bytes
    Flags: 0x002 (SYN)
    Window size value: 14600
    [Calculated window size: 14600]
    Checksum: 0xaf14 [validation disabled]
    Urgent pointer: 0
    Options: (20 bytes), Maximum segment size, SACK permitted, Timestamps, No-Operation (NOP), Window scale
        Maximum segment size: 1460 bytes
            Kind: Maximum Segment Size (2)
            Length: 4
            MSS Value: 1460
        TCP SACK Permitted Option: True
        Timestamps: TSval 51225, TSecr 0
        No-Operation (NOP)
        Window scale: 5 (multiply by 32)

```

now we can see it is making some empty TCP request to `9443`

## impersonating

### phone home

standing up a webserver on `9443`, we start to see traffic:

```
\x16\x03\x01\x02\x00\x01\x00\x01\xfc\x03\x03\xa1\xe1\x9d\x08\x88]*\xce\xe7G
```

```
\x16\x03\x01\x02\x00\x01\x00\x01\xfc\x03\x03Gg\xed\xa3m\x02\x88\xbd\xf0\xd1\x1eS\xf0\xfbc\xfb\x80K\x8dD\xed\xfb\x9b\x8c\xa0\xb2\xc6C\xc8\x15\x86\xbb\x00\x00\xa0\xc00\xc0,\xc0(\xc0$\xc0\x14\xc0
```

requests starting with `\x16\x03\x01` are almost certainly HTTPS requests coming over HTTP, so try to forge a usable cert:

```
$ openssl req -x509 -newkey rsa:2048 -keyout agents.cujo.io.pem -out agents.cujo.io.pem -days 365 -nodes
Generating a 2048 bit RSA private key
........................................................................................+++
..........................................................................................................+++
writing new private key to 'agents.cujo.io.pem'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:California
Locality Name (eg, city) []:Los Angeles
Organization Name (eg, company) [Internet Widgits Pty Ltd]:CUJO
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:agent.cujo.io
Email Address []:

$ openssl x509 -text -in agents.cujo.io.pem
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            e6:5b:e3:de:c4:4f:13:7e
        Signature Algorithm: sha1WithRSAEncryption
        Issuer: C=US, ST=California, L=Los Angeles, O=CUJO, CN=agent.cujo.io
        Validity
            Not Before: Nov 29 01:38:50 2016 GMT
            Not After : Nov 29 01:38:50 2017 GMT
        Subject: C=US, ST=California, L=Los Angeles, O=CUJO, CN=agent.cujo.io
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
            RSA Public Key: (2048 bit)
                Modulus (2048 bit):
                ...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Key Identifier:
                B2:33:5E:3A:3D:6E:B8:DC:D8:19:89:A2:B5:67:1C:99:B1:B0:2F:2F
            X509v3 Authority Key Identifier:
                keyid:...
                DirName:/C=US/ST=California/L=Los Angeles/O=CUJO/CN=agent.cujo.io
                serial:...

            X509v3 Basic Constraints:
                CA:TRUE
    Signature Algorithm: sha1WithRSAEncryption
        ...
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

