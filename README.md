# Traffic Limit ("traflimit")

## Limits amount of bandwidth that can be used by your Host/VPS/VM

This script will help you limit the amount of bandwidth that you consume so that you can predict/budget bandwidth fees while using Public Cloud services from providers such as AWS, IBM, MS Azure or Rackspace etc which bill based on bandwidth utilization.

**Features:**

- script is fully configurable (options inside)
- besides from cron it can run as daemon, screen or in foreground
- sends email and/or runs custom action(s) if traffic limit is hit like commands, other scripts etc
- includes `bashmail.sh` script, a small sendmail drop in replacement using... Bash :)

### Installation

1) Configure options in `traflimit.sh`, included comments explain what they do
2) Test by first setting `POLLMETHOD="foreground"`
3) Comment `POLLMETHOD` and create file in `/etc/cron.d`:

``` Bash
   echo "* * * * * root $PWD/traflimit.sh cron 2>&1" | sudo tee /etc/cron.d/traflimit
```

### Actions

When hitting the max traffic limit you can configure what should happen by setting `MAXRUNACT`. Remember you might have to add a `sleep 60` first so you have time to disable the script if needed (e.g if you used `shutdown` and boot after).

**Examples:**

- run command: `/sbin/iptables-restore < /etc/firewall-lockdown.conf`

- run script: `/root/scripts/max_traffic_action_script`

- iptables - flush/drop: `/sbin/iptables -F; /sbin/iptables -X; /sbin/iptables -P INPUT DROP; /sbin/iptables -P OUTPUT DROP; /sbin/iptables -P FORWARD DROP;`

- iptables - allow SSH only: `/sbin/iptables -A INPUT -i lo -j ACCEPT; /sbin/iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT; /sbin/iptables -A INPUT -j DROP;` `/sbin/iptables -A OUTPUT -o lo -j ACCEPT; /sbin/iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT; /sbin/iptables -A OUTPUT -j DROP;`

- stop network: `/etc/init.d/network* stop || /usr/sbin/service network stop || /usr/sbin/service networking stop || systemctl stop network*;`

- shutdown: `/sbin/shutdown -h 5 TrafficLimit hit && sleep 360;`

You could also make the script kill itself (included as an example and should not really be needed)

`logevent "INFO: Killing daemon process..."; pkill -9 -F $PIDFILE 2>/dev/null; rm $PIDFILE;`

### Max limit hit

After the max traffic limit was hit the actions you've defined in `MAXRUNACT` will continue to get executed everytime the script runs. To Acknowledge set `MAXACK="1"` and no actions will be run. To also disable log entries and mail limits optionally set `MAXQUIET="1"`.

You can also set these options by creating the following files in root dir:

``` bash
touch /.maxack
touch /.maxquiet
```

### Email alerts

If you want to be alerted by email you need need 'sendmail' or a compatible MTA (Mail Transfer Agent).
Postfix, Exim and SSMTP should all work. If it is not possible install one of these programs on your system you can use included `bashmail.sh` instead.

Make sure `MTA="/usr/sbin/sendmail"` in `traflimit.sh` is set correctly.

### Bashmail

First set `MTA="/path/to/bashmail.sh"` inside `traflimit.sh`. You'll also have to configure at least your SMTP server in `bashmail.sh` (e.g. "smtp.example.com"). Optionally you can enable Authentication and TLS.

### Sources

- Original TrafLimit Source: [besttechie.com/forums](https://www.besttechie.com/forums/topic/33745-linux-bandwidth-monitoring-script/)
- Original Bashmail Source: [33hops.com](https://33hops.com/send-email-from-bash-shell.html) (GPL-3.0)
