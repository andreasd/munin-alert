# Munin-alert

munin-alert is a perl script which handles [munin alerts](http://munin-monitoring.org/wiki/HowToContact)

# Features

Munin-alert send alerts to pagerduty, slack channel or hipchat room according to config file and event type. For example, you can send warnings to hipchat and pagerduty, critical errors to pagerduty, uknowns only to hipchat. Same munin-alert resolves alerts at pagerduty which cames with OK event type.

# Getting started

To use this script you need to install perl modules:

1. Digest::MD5
2. LWP::UserAgent
3. YAML
4. Sys::Syslog

You can accomplish this, by using:

```shell
perl -MCPAN -e shell
install LWP::UserAgent
```

You can also read [docs](http://www.cpan.org/modules/INSTALL.html) :)

# Usage

To use this script, simple add this options to munin.conf file:

```shell
contact.all.command /path/to/munin-alert.pl
```

And create /etc/munin-alert.yml config:

```yml
munin:
  critical:
    - pagerduty
    - hipchat
  warning:
    - hipchat
  ok:
    - pagerduty
    - hipchat
  unknown:
    - hipchat
hipchat:
  api_url: https://api.hipchat.com/v1/rooms/message
  api_key: 123
  room_id: 123
slack:
  token: 123
  channel: #123
  username: 123
  icon_url: http://123/123.png
pagerduty:
  api_url: https://events.pagerduty.com/generic/2010-04-15/create_event.json
  api_key: 123
```

Note: The slack functionality uses the API, not callbacks/integrations.

If you don't want to do anything with unknown events, just skip this option.

Don't forget to make munin-alert.pl executable:

```shell
chmod +x /path/to/munin-alert.pl
```
