# Traffic Limit ("traflimit")

## Limits amount of bandwidth that can be used by your Host/VPS/VM

This script will help you limit the amount of bandwidth that you consume so that you can predict/budget bandwidth fees while using services such as AWS, MS Azure, RackSpace Cloud etc which bill based on bandwidth utilization.

* ***Work in progress!***
* read script headers for details
* script is fully configurable (options inside)
* besides from cron it can run as daemon, screen or in foreground
* sends email and/or runs custom action(s) if traffic limit is hit like commands, other scripts etc
* includes `bashmail.sh` script, a small sendmail drop in replacement using... Bash :)

### Installation

1) Configure options in `traflimit.sh`, short comments explain what they do
2) Test by first setting `POLLMETHOD="foreground"`
3) Comment `POLLMETHOD` and add script to cron:

``` Bash
   echo "* * * * * root $PWD/traflimit.sh cron 2>&1" | sudo tee /etc/cron.d/traflimit
```

### Limit hit

After the max traffic limit was hit the actions you've defined in `MAXRUNACT` will continue to get executed everytime the script runs. To Acknowledge set `MAXACK="1"` and no actions will be run. To also disable log entries and mail limits optionally set `MAXQUIET="1"`.
