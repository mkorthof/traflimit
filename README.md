# Traffic Limit (traflimit)
### Limits amount of bandwidth that can be used by your host/vps/vm

This script will help you limit the amount of bandwidth that you consume so that you can predict/budget bandwidth fees while using services such as AWS, MS Azure, RackSpace Cloud etc which bill based on bandwidth utilization.

* ***Work in progress!***
* read script headers for details
* script is fully configurable
* besides from cron it can run as daemon, screen, in foreground
* sends email  and/or runs custom action(s) if traffic limit is hit (commands, other scripts etc) 
* includes ```bashmail.sh``` script, a small sendmail drop in replacement using... Bash :)

## Installation:
1) Configure options in ```traflimit.sh```
2) Test ./traflimit by first setting ```POLLMETHOD="foreground"```
3) Comment ```POLLMETHOD``` and add script to cron:
   ```echo "* * * * * root $PWD/traflimit.sh cron 2>&1" | sudo tee /etc/cron.d/traflimit```

