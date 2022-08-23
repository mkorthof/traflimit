#!/bin/bash

# 20211030 MK Traffic Limit

# This script will help you limit the amount of bandwidth that you consume so that you can predict/budget bandwidth fees
# while using services such as AWS, MS Azure, RackSpace Cloud etc which bill based on bandwidth utilization.

# Requires:	"vnstat" and *optionally* "screen" and "jq"
# Source:	https://www.besttechie.com/forums/topic/33745-linux-bandwidth-monitoring-script/

# --------------------

# check for {/usr/local,}/etc/traflimit.conf and in same dir as script
sc1="$(dirname "$0")/$(basename -s '.sh' "$0").conf"
sc2="${BASH_SOURCE[0]/%.sh/}.conf"
for i in "/usr/local/etc/traflimit.conf" "/etc/traflimit.conf" "$sc1" "$sc2"; do
	if [ -e "$i" ]; then
		scriptConf="$i"
		break
	fi
done
# source scriptConf if its non empty, else exit
if [ -n "$scriptConf" ] && [ -s "$scriptConf" ]; then
	source "$scriptConf" || {
		echo "Error: could not load $scriptConf"
		exit 1
	}
fi

logevent() {
	DATE="$(date +%F\ %T)"
	STRINGBASE="[$DATE]"
	MESSAGE="$*"
	echo "$STRINGBASE $MESSAGE"
	echo "$DATE $MESSAGE" | sed 's@\x1B\[[0-9;]*[a-zA-Z]@@g' >>$LOGFILE
}

mailevent() {
	if [ "$MTA" != "" ] && [ "$RCPTTO" != "" ]; then
		HEADER="To: <$RCPTTO>\n"
		if [ "$MAILFROM" ]; then
			HEADER+="From: $MAILFROM\n"
		fi
		echo -e "${HEADER}Subject: TrafficLimit: $1 - $HOSTNAME\n\nDate: $(date +%F\ %T)\nMessage: $2" | $MTA $RCPTTO
		EXITCODE="$?"
		if [ "$EXITCODE" -ne 0 ]; then
			logevent "ERROR: exit code \"$EXITCODE\" while running $MTA"
		fi
	fi
}

if [ -e "/.maxack" ]; then
	MAXACK="1"
fi
if [ -e "/.maxquiet" ]; then
	MAXQUIET="1"
fi

if [ "$VNSTATBIN" = "" ]; then
	VNSTATBIN="vnstat"
fi

# check for --update and --json support
JQ=0
JSON=0
VNSTATUPD=0
VNSTATVER=1
"$VNSTATBIN" --update >/dev/null 2>&1 && VNSTATUPD=1
"$VNSTATBIN" --json >/dev/null 2>&1 && JSON=1
vnstat --version | grep -Eq "^vnStat 2" && VNSTATVER=2

if [ "$JSON" -eq 1 ]; then
	which jq >/dev/null 2>&1 && JQ=1
fi

if [ "$1" = "cron" ]; then
	if [[ "$POLLMETHOD" =~ ^(screen|job|foreground)$ ]]; then
		logevent "ERROR: Script is being run from cron but \$POLLMETHOD is set to $POLLMETHOD."
		logevent "Config not possible, please either disable cron or change \$POLLMETHOD and then rerun this script."
		exit 1
	fi
	POLLMETHOD="cron"
else
	BOLD=$(tput bold)
	SGR0=$(tput sgr0)
	SMUL=$(tput smul)
	RMUL=$(tput rmul)
fi

runcmdas() {
	if [ "$RUNCMD" = "su" ]; then
		echo | su -c "$1" -s /bin/sh $RUNAS
	elif [ "$RUNCMD" = "sudo" ]; then
		eval sudo -n -u $RUNAS "$1"
	elif [ "$RUNCMD" = "none" ]; then eval "$1"; fi
	EXITCODE="$?"
	if [ "$EXITCODE" -ne 0 ]; then
		logevent "ERROR: exit code \"$EXITCODE\" while running $1"
	fi
}

getusage() {
	if [ "$JSON" -eq 1 ]; then
		if [ "$VNSTATVER" -eq 1 ]; then
			DIV="/1024"
		else
			DIV="/1024/1024"
		fi
		DATA="$(runcmdas "$VNSTATBIN -i $INTERFACE --json m")"
		if echo $DATA | grep -Eq "^Error:"; then
			logevent "$(echo "$DATA" | sed 's/^Error:/ERROR:/')"
			exit 1
		fi
		if [ "$JQ" -eq 1 ]; then
			TMP_IN="$(echo "$DATA" | jq '.interfaces|.[]|.traffic|.month//.months|.[-1].rx')"
			TMP_OUT="$(echo "$DATA" | jq '.interfaces|.[]|.traffic|.month//.months|.[-1].tx')"
		else
			TMP="$(echo "$DATA" | sed -r 's/.*\{"id":[0-9],"date":\{"year":[0-9]{4},"month":[0-9]+\},"rx":([0-9]+),"tx":([0-9]+)\}.*/\1 \2/')"
			TMP_IN="$(echo "$TMP" | cut -d' ' -f1)"
			TMP_OUT="$(echo "$TMP" | cut -d' ' -f2)"
		fi
		INCOMING="$((TMP_IN${DIV}))"
		OUTGOING="$((TMP_OUT${DIV}))"
	else
		DATA="$(runcmdas "$VNSTATBIN --dumpdb -i $INTERFACE | grep 'm;0'")"
		INCOMING="$(echo "$DATA" | cut -d\; -f4)"
		OUTGOING="$(echo "$DATA" | cut -d\; -f5)"
	fi
	TOTUSAGE="$((INCOMING + OUTGOING))"
	if [ "$DEBUG" -eq 1 ]; then TOTUSAGE=1048577; fi
	if [ $TOTUSAGE -ge $MAX ]; then
		if [ $MAXACK -eq 1 ]; then
			if [ $MAXQUIET -ne 1 ]; then
				logevent "${BOLD}$TOTUSAGE${SGR0}/$MAX MiB of monthly bandwidth has been used ($INTERFACE) - Acknowledged"
				mailevent Ack "$TOTUSAGE/$MAX MiB of monthly bandwidth has been used ($INTERFACE) - Acknowledged\nAction: None (skipped)"
				sleep 900
			fi
		else
			logevent "${BOLD}$TOTUSAGE${SGR0}/$MAX MiB of monthly bandwidth has been used ($INTERFACE); bandwidth-saving precautions are being run"
			mailevent Alert "$TOTUSAGE/$MAX MiB of monthly bandwidth has been used ($INTERFACE); bandwidth-saving precautions are being run\nAction: $MAXRUNACT"
			eval "$MAXRUNACT"
			sleep 900
		fi
	else
		if [ "$POLLMETHOD" = "foreground" ]; then
			logevent "${BOLD}$TOTUSAGE${SGR0}/$MAX MiB of monthly bandwidth has been used ($INTERFACE); system is clear for the time being"
		fi
	fi
	if [ "$POLLMETHOD" != "cron" ]; then
		sleep $INTERVAL
		getusage
	fi
}

if [ "$(id -u)" -ne 0 ]; then
	echo "[$(date +%F\ %T)] ERROR: Please run this script as root."
	exit 1
elif [ "$AGREE" != "YES" ]; then
	logevent "INFO: Please make sure you understand what this script does, read the header and check that ${BOLD}\$MAXRUNACT${SGR0} is set correctly."
	logevent "When you have reached the maximum amount of traffic ${BOLD}\$MAX${SGR0} the ${BOLD}\$MAXRUNACT${SGR0} default is: ${SMUL}run iptables to allow only ssh traffic${RMUL}."
	logevent "To confirm please set ${BOLD}\$AGREE${SGR0} to \"${BOLD}YES${SGR0}\" and restart."
	exit 0
elif [ -x "$VNSTATBIN" ]; then
	logevent "ERROR: \"vnstat\" binary does not exist or is not executable. Please make sure vnStat is installed correctly."
	exit 1
elif [ "$(whereis vnstat)" = "vnstat:" ]; then
	logevent "ERROR: It appears that you do not have \"vnstat\" installed. Please install this package and restart."
	exit 1
elif [ "$UPDATEMETHOD" = "vnstatd" ] && [ ! "$(pgrep vnstatd)" ]; then
	logevent "ERROR: It appears that \"vnstatd\" is not running."
	logevent "Please make sure it is started first or change ${BOLD}\$POLLMETHOD${SGR0} to \"vnstat-u\" and then rerun this script."
	exit 1
elif [ "$UPDATEMETHOD" = "vnstat-u" ] && [ "$(pgrep vnstatd)" ]; then
	logevent "ERROR: It appears that \"vnstatd\" is running but ${BOLD}\$POLMETHOD${SGR0} is set to \"vnstat-u\."
	logevent "Config not possible, please either disable vnstatd or change ${BOLD}\$POLLMETHOD${SGR0} and then rerun this script."
	exit 1
elif [ "$UPDATEMETHOD" = "vnstat-u" ] && [ "$VNSTATUPD" -eq 0 ]; then
	logevent "ERROR: Vnstat 2.x does not support '-u' parameter to update database."
	logevent "Config not possible, please set enable vnstatd as ${BOLD}\$UPDATEMETHOD${SGR0} and then rerun this script."
	exit 1
elif [[ ! "$POLLMETHOD" =~ ^(screen|job|cron|foreground)$ ]]; then
	logevent "ERROR: No method found to keep the script running. Please define this or run from cron."
	exit 1
elif [ "$RUNCMD" = "sudo" ] && [ ! "$(sudo -l vnstat 2>/dev/null)" ]; then
	logevent "ERROR: Unable to run \"sudo vnstat\". Please check your sudo config or change ${BOLD}\$RUNCMD${SGR0} to \"su\" or \"none\"."
	exit 1
elif [ "$MTA" != "" ] && [ ! -x "$MTA" ]; then
	logevent "ERROR: Sendmail does not exist or is not executable. Please check ${BOLD}\$MTA${SGR0} or it leave empty to disable sending mail."
	exit 1
elif [ "$MTA" != "" ] && [ "$RCPTTO" = "" ]; then
	logevent "ERROR: Mail receipient (${BOLD}\$RCPTTO${SGR0}) has not been defined. Please define this and restart. Leave \$MTA empty to disable sending mail."
	exit 1
elif [ "$INTERFACE" = "" ]; then
	logevent "ERROR: You have not defined the interface network (${BOLD}\$INTERFACE${SGR0}) that you want to monitor. Please define this and restart."
	exit 1
elif [ $MAX == "" ]; then
	logevent "ERROR: The maximum monthly traffic level (${BOLD}\$MAX${SGR0}) has not been defined. Please define this and restart."
	exit 1
elif [ -s $PIDFILE ]; then
	if [ "$(pgrep -F $PIDFILE 2>/dev/null)" ]; then
		PSINFO="$(pgrep -F $PIDFILE | xargs --no-run-if-empty ps -ho user,pid,tty,start,cmd -p | sed 's/  */ /g')"
		logevent "INFO: Already running as: \"$PSINFO\""
		exit 0
	else
		logevent "INFO: Stale pidfile, deleting $PIDFILE"
		rm $PIDFILE
	fi
fi
echo "$$" >$PIDFILE

if [ "$POLLMETHOD" = "screen" ]; then
	if [ "$(whereis screen)" = "screen:" ]; then
		logevent "ERROR: It appears that you do not have \"screen\" installed. Please install this package and restart."
		exit 1
	else
		if [ "$1" = "doscreen" ]; then
			getusage
		else
			if [ "$UPDATEMETHOD" = "vnstat-u" ]; then
				logevent "Starting vnstat interface logging on $INTERFACE"
				mailevent Starting "Starting vnstat interface logging on $INTERFACE with a maximum of ${MAX}MiB traffic per month"
				runcmdas "$VNSTATBIN -u -i $INTERFACE"
			fi
			logevent "INFO: Initiating screen session to run as a daemon process"
			screen -d -m "$0" doscreen
		fi
	fi
fi

if [ "$POLLMETHOD" = "cron" ]; then
	for i in $(seq 1 $CRONMAX); do
		if [ "$i" -gt 1 ]; then sleep $INTERVAL; fi
		getusage
	done
	if [ -s $PIDFILE ]; then rm $PIDFILE; fi
	exit 0
fi

if [ "$POLLMETHOD" = "job" ]; then
	if [ "$UPDATEMETHOD" = "vnstat-u" ]; then
		logevent "Starting vnstat interface logging on $INTERFACE"
		mailevent Starting "Starting vnstat interface logging on $INTERFACE with a maximum of ${MAX}MiB traffic per month"
		runcmdas "$VNSTATBIN -u -i $INTERFACE"
	fi
	logevent "INFO: Starting daemon process..."
	getusage </dev/null >/dev/null 2>&1 &
	echo "$!" >$PIDFILE
	disown
	exit 0
fi

if [ "$POLLMETHOD" = "foreground" ]; then
	if [ "$UPDATEMETHOD" = "vnstat-u" ]; then
		logevent "Starting vnstat interface logging on $INTERFACE"
		mailevent Starting "Starting vnstat interface logging on $INTERFACE with a maximum of ${MAX}MiB traffic per month"
		runcmdas "$VNSTATBIN -u -i $INTERFACE"
	fi
	logevent "INFO: Starting process in foreground. Press ${BOLD}CTRL-C${SGR0} to abort."
	trap '{ logevent "INFO: Exiting..."; if [ -s $PIDFILE ]; then rm $PIDFILE; fi; exit 0; }' HUP INT QUIT TERM
	getusage
	exit 0
fi

# vim: set noet sts=0 sw=4 ts=4:
