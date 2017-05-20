# Traffic Limit (traflimit)
Limits amount of bandwidth that can be used by your host/vps/vm

* ***Work in progress!***
* read script headers for details
* includes ```bashmail.sh``` script, a small sendmail drop in replacement using... Bash :)
* final script should be finished soon (few weeks max.)

## Installation:
1) Configure options in ```traflimit.sh```
2) Test ./traflimit by first setting ```POLLMETHOD="foreground"```
3) Comment ```POLLMETHOD``` and add script to cron:
   ```echo "* * * * * root $PWD/traflimit.sh cron 2>&1" | sudo tee /etc/cron.d/traflimit```

