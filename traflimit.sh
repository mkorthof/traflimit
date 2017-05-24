#!/bin/bash

# 20170315 MK Traffic Limit

# This script will help you limit the amount of bandwidth that you consume so that you can predict/budget bandwidth fees
# while using services such as AWS, MS Azure, RackSpace Cloud etc which bill based on bandwidth utilization.

# Requires:	"vnstat" and *optionally* "screen"
# Source:	https://www.besttechie.com/forums/topic/33745-linux-bandwidth-monitoring-script/

AGREE=""

# Maximum amount of bandwidth (megabytes) that you want to consume in a given month before anti-overage commands are run
MAX=1048576

# Interface that you would like to monitor (typically "eth0")
INTERFACE="eth0"

# Optional location vnStat binary (default is none)
#VNSTATBIN="/usr/bin/vnstat"

# Run vnstat as another user (default is "vnstat")
RUNAS="vnstat"

# How to run as another user: "su", "sudo" or "none" (default is "su")
RUNCMD="sudo"

# Mail Transfer Agent. A lightweight send-only MTA such as SSMTP should work fine. Or leave empty to disable sending mail.
# If you do not have a MTA installed you can use the included "bashmail.sh" script. Default is "/usr/sbin/sendmail"
MTA="/usr/sbin/sendmail"

# E-mail adress to receive notifications
RCPTTO="admin@example.com"

# Optional e-mail address from which to sent notifications ("From:"). Default is none
MAILFROM="TrafficLimit <traflimit@example.com>"

# Use one of these methods to keep the script running in the background
# Default is to use cron, uncomment to change to: "screen", "job" or "foreground"
#POLLMETHOD="foreground"

# Should the script run vnstat -u to update the vnstat database or are you using the vnstatd daemon
# Default is "vnstatd", can be changed to: "vnstat-u"
UPDATEMETHOD="vnstatd"

# Interval between polling stats, in seconds
INTERVAL="30"

# How many times total to poll stats per cronjob 
# Example: if cron is set to run every minute (eg "* * * * *"), interval is set
# to "30" and this is set to "2" the script will poll at 9:00:00 and 9:00:30
CRONMAX="2"

# Action to perform when hitting max traffic limit. For example: flush iptables, stop network or shutdown.
# Make sure you set this correctly. Default is: run iptables to allow only ssh traffic (!)
MAXRUNACT='(
  sleep 60;
  echo "DEBUG: MAXRUNACT";
  logevent "DEBUG: Now i would have flushed iptables, stopped network or run shutdown...":
  sleep 360;
  exit 0
)'


# MAXRUNACT Examples:

# run command:           /sbin/iptables-restore < /etc/firewall-lockdown.conf
# run script:            /root/scripts/max_traffic_action_script
# iptables flush/drop:   /sbin/iptables -F; /sbin/iptables -X; /sbin/iptables -P INPUT DROP; /sbin/iptables -P OUTPUT DROP; /sbin/iptables -P FORWARD DROP;
# iptables ssh only:     /sbin/iptables -A INPUT -i lo -j ACCEPT; /sbin/iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT; /sbin/iptables -A INPUT -j DROP;
#                        /sbin/iptables -A OUTPUT -o lo -j ACCEPT; /sbin/iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT; /sbin/iptables -A OUTPUT -j DROP;
# stop network:	         /etc/init.d/network* stop || /usr/sbin/service network stop || /usr/sbin/service networking stop || systemctl stop network*;
# shutdown:              /sbin/shutdown -h 5 TrafficLimit hit && sleep 360;

# usuallly not needed:   logevent "INFO: Killing daemon process..."; pkill -9 -F $PIDFILE 2>/dev/null; rm $PIDFILE;

PIDFILE="/var/run/traflimit.pid"
LOGFILE="/var/log/traflimit.log"

# END of configuration
# --------------------

logevent() {
	DATE="$( date +%F\ %T )"; STRINGBASE="[$DATE]"; MESSAGE="$@"
	echo "$STRINGBASE $MESSAGE"
	echo "$DATE $MESSAGE" | sed 's@\x1B\[[0-9;]*[a-zA-Z]@@g' >> $LOGFILE
}

mailevent() {
	if [ "$MTA" != "" ] && [ "$RCPTTO" != "" ]; then
		HEADER="To: <$RCPTTO>\n"; if [ "$MAILFROM" ]; then HEADER+="From: $MAILFROM\n"; fi
		echo -e "${HEADER}Subject: TrafficLimit: $1 - $HOSTNAME\n\nDate: $( date +%F\ %T )\nMessage: $2" | $MTA $RCPTTO
		EXITCODE="$?"; if [ "$EXITCODE" -ne 0 ]; then logevent "ERROR: exit code \"$EXITCODE\" while running $MTA"; fi
	fi
}

if [ "$VNSTATBIN" = "" ]; then VNSTATBIN="vnstat"; fi

if [ "$1" = "cron" ]; then
	if [[ "$POLLMETHOD" =~ ^(screen|job|foreground)$ ]]; then
		logevent "ERROR: Script is being run from cron but \$POLLMETHOD is set to $POLLMETHOD."
		logevent "Config not possible, please either disable cron or change \$POLLMETHOD and then rerun this script."; exit 1
	fi
	POLLMETHOD="cron"
else
	BOLD=$( tput bold )
	SGR0=$( tput sgr0 )
	SMUL=$( tput smul )
	RMUL=$( tput rmul )
fi

runcmdas() {
	if [ "$RUNCMD" = "su" ]; then echo | su -c "$1" -s /bin/sh $RUNAS
	elif [ "$RUNCMD" = "sudo" ]; then eval sudo -n -u $RUNAS "$1"
	elif [ "$RUNCMD" = "none" ]; then eval "$1"; fi
	EXITCODE="$?"; if [ "$EXITCODE" -ne 0 ]; then logevent "ERROR: exit code \"$EXITCODE\" while running $1"; fi
}

getusage() {
	DATA=$( runcmdas "$VNSTATBIN --dumpdb -i $INTERFACE | grep 'm;0'" )
        INCOMING=$( echo $DATA | cut -d\; -f4 )
        OUTGOING=$( echo $DATA | cut -d\; -f5 )
        TOTUSAGE=$( expr $INCOMING + $OUTGOING )
#DEBUG:
#TOTUSAGE=1048577
        if [ $TOTUSAGE -ge $MAX ]; then
		logevent "$( echo ${BOLD}$TOTUSAGE${SGR0}/$MAX )MB of monthly bandwidth has been used ($INTERFACE); bandwidth-saving precautions are being run"
		mailevent Alert "$( echo $TOTUSAGE/$MAX )MB of monthly bandwidth has been used ($INTERFACE); bandwidth-saving precautions are being run\nAction: $MAXRUNACT"
		eval "$MAXRUNACT"
		sleep 900
        else
		if [ "$POLLMETHOD" = "foreground" ]; then
			logevent "$( echo ${BOLD}$TOTUSAGE${SGR0}/$MAX )MB of monthly bandwidth has been used ($INTERFACE); system is clear for the time being"
		fi
        fi
	if [ "$POLLMETHOD" != "cron" ]; then
	        sleep $INTERVAL
        	getusage
	fi
}

MSGPLS="Please make sure"; MSGEXE="does not exist or is not executable."; MSGITA="It appears that"; MSGDEF="Please define this and restart."
if [ $( id -u ) -ne 0 ]; then echo "[$( date +%F\ %T )] ERROR: Please run this script as root."; exit 1
elif [ "$AGREE" != "YES" ]; then logevent "INFO: $MSGPLS you understand what this script does, read the header and check that ${BOLD}\$MAXRUNACT${SGR0} is set correctly."
	logevent "When you have reached the maximum amount of traffic ${BOLD}\$MAX${SGR0} the ${BOLD}\$MAXRUNACT${SGR0} default is: ${SMUL}run iptables to allow only ssh traffic${RMUL}."
	logevent "To confirm please set ${BOLD}\$AGREE${SGR0} to \"${BOLD}YES${SGR0}\" and restart."; exit 0
elif [ -x "$VNSTATBIN" ]; then logevent "ERROR: \"vnstat\" binary $MSGEXE $MSGPLS vnStat is installed correctly."; exit 1
elif [ "$( whereis vnstat )" = "vnstat:" ]; then logevent "ERROR: $MSGITA you do not have \"vnstat\" installed. Please install this package and restart."; exit 1
elif [ "$UPDATEMETHOD" = "vnstatd" ] && [ ! "$( pgrep vnstatd )" ]; then logevent "ERROR: $MSGITA \"vnstatd\" is not running."
	logevent "$MSGPLS it is started first or change ${BOLD}\$POLLMETHOD${SGR0} to \"vnstat-u\" and then rerun this script."; exit 1
elif [ "$UPDATEMETHOD" = "vnstat-u" ] && [ "$( pgrep vnstatd )" ]; then logevent "ERROR: $MSGITA \"vnstatd\" is running but ${BOLD}\$POLMETHOD${SGR0} is set to \"vnstat-u\."
	logevent "Config not possible, please either disable vnstatd or change ${BOLD}\$POLLMETHOD${SGR0} and then rerun this script."; exit 1
elif [[ ! "$POLLMETHOD" =~ ^(screen|job|cron|foreground)$ ]]; then logevent "ERROR: No method found to keep the script running. Please define this or run from cron."; exit 1
elif [ "$RUNCMD" = "sudo" ] && [ ! "$( sudo -l vnstat 2>/dev/null )" ]; then logevent "ERROR: Unable to run \"sudo vnstat\". Please check your sudo config or change ${BOLD}\$RUNCMD${SGR0} to \"su\" or \"none\"."; exit 1
elif [ "$MTA" != "" ] && [ ! -x "$MTA" ]; then logevent "ERROR: Sendmail $MSGEXE Please check ${BOLD}\$MTA${SGR0} or it leave empty to disable sending mail."; exit 1
elif [ "$MTA" != "" ] && [ "$RCPTTO" = "" ]; then logevent "ERROR: Mail receipient (${BOLD}\$RCPTTO${SGR0}) has not been defined. $MSGDEF Leave \$MTA empty to disable sending mail."; exit 1
elif [ "$INTERFACE" = "" ]; then logevent "ERROR: You have not defined the interface network (${BOLD}\$INTERFACE${SGR0}) that you want to monitor. $MSGDEF"; exit 1
elif [ $MAX == "" ]; then logevent "ERROR: The maximum monthly traffic level (${BOLD}\$MAX${SGR0}) has not been defined. $MSGDEF"; exit 1
elif [ -s $PIDFILE ]; then
	if [ "$( pgrep -F $PIDFILE 2>/dev/null )" ]; then
		PSINFO="$( pgrep -F $PIDFILE | xargs --no-run-if-empty ps -ho user,pid,tty,start,cmd -p | sed 's/  */ /g' )";
		logevent "INFO: Already running as: \"$PSINFO\""; exit 0
	else
		logevent "INFO: Stale pidfile, deleting $PIDFILE"; rm $PIDFILE
	fi
fi
echo "$$" > $PIDFILE

if [ "$POLLMETHOD" = "screen" ]; then
	if [ "$( whereis screen )" = "screen:" ]; then
		logevent "ERROR: $MSGITA you do not have \"screen\" installed. Please install this package and restart."
		exit 1
	else
		if [ "$1" = "doscreen" ]; then
			getusage
		else
			if [ "$UPDATEMETHOD" = "vnstat-u" ]; then
				logevent "Starting vnstat interface logging on $INTERFACE"
				mailevent Starting "Starting vnstat interface logging on $INTERFACE with a maximum of ${MAX}MB traffic per month"
				runcmdas "$VNSTATBIN -u -i $INTERFACE"
			fi
			logevent "INFO: Initiating screen session to run as a daemon process"
			screen -d -m $0 doscreen
		fi
		#fi
	fi
fi

if [ "$POLLMETHOD" = "cron" ]; then
	for i in $( seq 1 $CRONMAX ); do
		if [ "$i" -gt 1 ]; then sleep $INTERVAL; fi
		getusage
	done
	if [ -s $PIDFILE ]; then rm $PIDFILE; fi
	exit 0
fi

if [ "$POLLMETHOD" = "job" ]; then
	if [ "$UPDATEMETHOD" = "vnstat-u" ]; then
		logevent "Starting vnstat interface logging on $INTERFACE" 
		mailevent Starting "Starting vnstat interface logging on $INTERFACE with a maximum of ${MAX}MB traffic per month"
		runcmdas "$VNSTATBIN -u -i $INTERFACE"
	fi
	logevent "INFO: Starting daemon process..."
	getusage </dev/null >/dev/null 2>&1 &
	echo "$!" > $PIDFILE
	disown
	exit 0
fi

if [ "$POLLMETHOD" = "foreground" ]; then
	if [ "$UPDATEMETHOD" = "vnstat-u" ]; then
		logevent "Starting vnstat interface logging on $INTERFACE" 
		mailevent Starting "Starting vnstat interface logging on $INTERFACE with a maximum of ${MAX}MB traffic per month"
		runcmdas "$VNSTATBIN -u -i $INTERFACE"
	fi
	logevent "INFO: Starting process in foreground. Press ${BOLD}CTRL-C${SGR0} to abort."
 	trap '{ logevent "INFO: Exiting..."; if [ -s $PIDFILE ]; then rm $PIDFILE; fi; exit 0; }' HUP INT QUIT TERM
	getusage
	exit 0
fi
