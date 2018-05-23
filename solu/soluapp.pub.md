# solu.pub vulnerabilities

## intro

  * [persistent XSS](#XSS)
  * [HTTP passing passwords in clear](#cleartext-passwords)
  * [incremental IDs for users and posts](#incremental-ids)
  * [last_story1.php vs. last_story.php](#last_story.php)
  * [creating stories with free account](#free-account-story-creation)

## XSS

on http://soluapp.pub/legacy/legacy-chapter1.php, both are persistent:

  * Legacy Title
  * Chapter Title (is run 2x per page load)

POC input value: `"><script>alert('foo')</script>`

given the basic nature of this string, imagining that many of the other input fields are similarly vulnerable,
and that no XSS mitigation whatsoever is being done.

## HTTP passing cleatext passwords

i couldn't find any resources on this site that were served over SSL, and of particular concern is the email (login page)[http://soluapp.pub/signin2.html], which sends:

```
POST /php/signin.php HTTP/1.1
Host: soluapp.pub
Connection: keep-alive
Content-Length: 61
Accept: */*
Origin: http://soluapp.pub
X-Requested-With: XMLHttpRequest
User-Agent: <redacted>
Referer: http://soluapp.pub/signin2.html
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.8
Cookie: PHPSESSID=<redacted>; intercom-id-l2bhyx5c=85d1329e-1353-4c01-b4fa-e48e14c6d985; _gat=1; _ga=GA1.2.1803746552.1482791071

&Email_Address=<redacted>&Password=<redacted>
```

## incremental IDs

## last_story.php

public entrance/landing page URLs:
  * http://soluapp.pub/legacy-chapter.php?id=2074 -- <user1> (randomly chosen)
  * http://soluapp.pub/legacy-chapter.php?id=917  -- <user2> (free)
  * http://soluapp.pub/legacy-chapter.php?id=5288 -- <user3> (paid)

public story URL:
  * http://soluapp.pub/story_slide.php?userid=196&ty=I%20came%20for%20the%20winter...&key=0

private/editing pages had the following URLs:
  * http://soluapp.pub/legacy/last_story1.php?userid=882&id=5288&img=bg_image7.png&key=0&ty=&chapkey=0
  * http://soluapp.pub/legacy/write_legacy.php?id=5288&img=&key=&chapkey=&ty=&user=882

simply by changing the userid (or post id) and using the /legacy/ URLs, even while logged in as my user,
i am able to make unauthorized changes.

to find more users, one could simply try 0..10_000 as userid values in

## free account story creation

by visiting while signed in with a free account, these allow creation of stories:
  * http://soluapp.pub/record_next.php
  * http://soluapp.pub/all_chapter1_alt.php

`http://soluapp.pub/legacy/write_legacy.php?id=&img=&key=&chapkey=&ty=&user=917` leaks path information:
```
<b>Fatal error</b>:  Call to a member function fetch_assoc() on a non-object in <b>/home/soluapp/public_html/legacy/write_legacy.php</b> on line <b>620</b><br />
```

---
http://soluapp.pub/audio_record.php?story_title=%22%3E%3Cscript%3Ealert%28%27foo%27%29%3C%2Fscript%3E&audio=
