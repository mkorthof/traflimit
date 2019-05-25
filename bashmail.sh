#!/bin/bash 

############################################################################# 
# 
# Minimal e-mail client 
# By Daniel J. Garcia Fidalgo (33HOPS) daniel.garcia@33hops.com 
# Copyright (C) 2013 33HOPS, Sistemas de Información y Redes, S.L. 
# 
# This program is free software: you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by 
# the Free Software Foundation, either version 3 of the License, or 
# (at your option) any later version. 
# 
# This program is distributed in the hope that it will be useful, 
# but WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
# GNU General Public License for more details. 
# 
# You should have received a copy of the GNU General Public License 
# along with this program. If not, see 
# http://www.gnu.org/licenses/gpl-3.0.en.html 
# 
############################################################################# 

#############################################################################
# 20190307 MK: bashmail.sh
# Changes: added stdin input, ssl/tls support
# Dependencies: base64 (openssl, nc)
#############################################################################

mailto="$1"
subject="$2"
body="$3"
debug=0

################################################## 
## CONFIGURATION VARIABLES
################################################## 

#smtpsrv="smtp.mydomain.com"  # smtp server
#HOSTNAME="mydomain.com"      # set host env var

#mailto="me.myself@mydomain.com" 
#mailfrom="me@mydomain.com" 
#subject="Test bashmail.sh" 

html=0  # set to 1 to create html email
auth=0  # set to 1 to enable user/password auth
nl="\n" # set newlines (e.g. "\n" or "\r\n")

## Don't use TLS, plaintext user/password auth:
################################################## 
starttls=0
smtpport="25" 
#smtpusr="$( echo -ne me@mydomain.com | base64 )" 
#smtppwd="$( echo -ne mypassw0rd | base64 )" 

## Use TLS
################################################## 
# use port 25, 465 or 589 below
#starttls=1
#smtpport="587"

## Read base64 user/password from file:
################################################## 
# create a file .mail containing 2 variables
# for example:
#   user=yu2otDJ==
#   password=9OTafrRe=
#source ~user/.mail
#smtpusr=$( echo -n $user )
#smtppwd=$( echo -n $password )

################################################## 
## END OF CONFIGURATION
################################################## 

err_exit() { echo -e 1>&2; exit 1; } 

if [ ! $smtpsrv ]; then echo; echo \$smtpsrv missing!; err_exit; fi
if [ ! $smtpport ]; then echo; echo \$smtpport missing!; err_exit; fi
if [ $auth -eq 1 ]; then
  if [ ! $smtpusr ]; then echo; echo \$smtpusr missing!; err_exit; fi
  if [ ! $smtppwd ]; then echo; echo \$smtppwd missing!; err_exit; fi
fi
if [ ! $mailfrom ]; then echo; echo \$mailfrom missing!; err_exit; fi

run_sclient() {
  cmd="openssl s_client -connect ${smtpsrv}:${smtpport}"
  if [ "$debug" = 0 ]; then
    $cmd $@ "-quiet" >/dev/null 2>&1
  else 
    $cmd $@
  fi
  if [ "$?" != 0 ]; then err_exit; fi
}

stdin=255
if [ "$mailto" ] && [ "$subject" ] && [ "$body" ]; then
  stdin=0
else
  if [ "$mailto" = "" ]; then
    echo; echo "$0 <address>"; err_exit;
  else
    stdin=1
    body="$( cat )"
  fi
fi

mail_input() { 
  sleep 2
  echo "helo ${HOSTNAME}" || echo "ehlo ${HOSTNAME}" 
  if [ $auth -eq 1 ]; then echo "AUTH LOGIN"; echo "${smtpusr}"; echo "${smtppwd}"; fi
  echo "MAIL FROM:<${mailfrom}>"
  echo "RCPT TO:<${mailto}>"
  echo "DATA"
  if [ $html -eq 1 ]; then echo "Content-type: text/html"; fi
  if [ $stdin -eq 0 ]; then
    echo "From: <${mailfrom}>"
    echo "To: <${mailto}>"
    echo "Subject: ${subject}"
    echo
  fi
  sleep 1
  echo -e "${body}"
  echo -e "${nl}.${nl}QUIT"
  sleep 1
} 

# You may directly send the protocol conversation via TCP:
# mail_input > /dev/tcp/$smtpsrv/$smtpport || err_exit 

# If you have nc (netcat) available in your system this 
# will offer you the protocol conversation on screen:
# mail_input | nc $smtpsrv $smtpport || err_exit 

# If on addition you have OpenSSL you can send your e-mail under TLS 

if [ $debug -eq 2 ]; then
  set -x
fi
if [ $smtpport -eq 25 ]; then
  if [ $starttls -eq 0 ]; then mail_input | telnet ${smtpsrv} ${smtpport} || err_exit # telnet
  else mail_input | run_sclient -starttls smtp || err_exit; fi # openssl starttls
elif [ $smtpport -eq 465 ]; then mail_input | run_sclient || err_exit # openssl
elif [ $smtpport -eq 587 ]; then mail_input | run_sclient -starttls smtp || err_exit # openssl starttls
fi
set +x
