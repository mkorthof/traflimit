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
#
# Version: 20200815 (MK) "bashmail.sh"
# Original: https://33hops.com/send-email-from-bash-shell.html
# Changes: added stdin input, ssl/tls support
# Dependencies: base64 (optionally: openssl, nc)
#
#############################################################################

mailto="$1"
subject="$2"
body="$3"

# Set to 1 or 2 to view stdout in case of issues
debug=0

################################################## 
## CONFIGURATION VARIABLES
################################################## 

# (Req)uired and (Opt)ional settings
# (Arg)uments can also be specified from CLI

#HOSTNAME="example.com"            # (Opt) Set envvar for 'helo'
smtpsrv="smtp.example.com"         # (Req) SMTP Server
mailfrom="me@example.com"          # (Req) From Address
#mailto="me.myself@example.com"    # (Arg) To Address
#subject="Test bashmail"            # (Arg) Subject

html=0        # (Opt) Set to 1 to create html email
auth=1        # (Opt) Set to 1 to enable user/password auth
nl="\r\n"     # (Req) Set newlines (e.g. "\n" or "\r\n")

## Do not use TLS:
################################################## 
starttls=0
smtpport="25" 

## (Opt) Use TLS:
################################################## 
# Set port below to 25, 465 or 587
starttls=1
smtpport="587"

## (Opt) Plaintext user/password auth:
################################################## 
#smtpusr="$( echo -ne me@example.com | base64 )" 
#smtppwd="$( echo -ne mypassw0rd | base64 )" 

## (Opt) Read base64 user/password from file:
################################################## 
# create a file '.mail' with 2 variables in b64
# for example:
#   user=yu2otDJ==
#   password=9OTafrRe=
#source $HOME/.mail
#smtpusr=$( echo -n $user )
#smtppwd=$( echo -n $password )

################################################## 
## END OF CONFIGURATION
################################################## 

set -eo pipefail

err_exit() {
  echo -e 1>&2
  exit 1
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

run_sclient() {
  cmd="openssl s_client -connect ${smtpsrv}:${smtpport}"
  if [ "$debug" = 0 ]; then
    $cmd $@ "-quiet" >/dev/null 2>&1
  else
    $cmd $@
  fi
  if [ "$?" != 0 ]; then err_exit; fi
}

mail_input() { 
  sleep 2
  echo "helo ${HOSTNAME}" || echo "ehlo ${HOSTNAME}" 
  if [ $auth -eq 1 ]; then
    echo "AUTH LOGIN"; echo "${smtpusr}"; echo "${smtppwd}"
  fi
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

if [ -z $smtpsrv ]; then
  echo
  echo \$smtpsrv missing!
  err_exit
fi
if [ $auth -eq 1 ]; then
  if [ -z $smtpusr ]; then echo; echo \$smtpusr missing!; err_exit; fi
  if [ -z $smtppwd ]; then echo; echo \$smtppwd missing!; err_exit; fi
fi
if [ -z $mailfrom ]; then echo; echo \$mailfrom missing!; err_exit; fi

# You may directly send the protocol conversation via TCP:
# mail_input > /dev/tcp/$smtpsrv/$smtpport || err_exit 

# If you have nc (netcat) available in your system this 
# will offer you the protocol conversation on screen:
# mail_input | nc $smtpsrv $smtpport || err_exit 

# If on addition you have OpenSSL you can send your e-mail under TLS 

if [ $debug -ge 2 ]; then
  set -x
fi
case $smtpport in
  25) if [ $starttls -eq 0 ]; then
        mail_input | telnet "${smtpsrv}" "${smtpport}" || err_exit    # telnet
      else
        mail_input | run_sclient -starttls smtp || err_exit;          # openssl starttls
      fi ;;
  465) mail_input | run_sclient || err_exit ;;                        # openssl
  587) mail_input | run_sclient -starttls smtp || err_exit ;;         # openssl starttls
  *) echo; echo \$smtpport missing!; err_exit ;;
esac
set +x

