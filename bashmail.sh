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
# 20170315 MK bashmail
# Changes: added stdin input, ssl/tls support
#############################################################################

################################################## 
## Dependencies: base64, nc 
## VARIABLES CONFIGURABLES 
################################################## 

auth=1

################################################## 
# Example 1: no tls, plain text user/passwd)
################################################## 
#HOSTNAME="mydomain.com" 
#smtpsrv="smtp.mydomain.com" 
#smtpport="25" 
#smtpusr="$( echo -ne me@mydomain.com | base64 )" 
#smtppwd="$( echo -ne m\|passw0rd | base64 )" 
#mailfrom="me@mydomain.com" 
#mailto="me.myself@mydomain.com" 
#subject="HELLO AGAIN" 

################################################## 
# Example 2: starttls, base64 user/passwd from file
# The file ~/.mail contains 2 variables:
# user=dXNlcgo=
# password=cGFzc3dkCg==
################################################## 
starttls=1
smtpsrv="smtp.example.com"
smtpport="587" 
source ~user/.mail
smtpusr=$( echo -n $user )
smtppwd=$( echo -n $password )
mailfrom="traflimit@example.com"
mailto="$1"
subject="$2"
body="$3"

html=0


################################################## 
## FINAL DE VARIABLES CONFIGURABLES 
################################################## 

#newline=$'\012' 

function err_exit() { echo -e 1>&2; exit 1; } 

if [ ! $smtpsrv ]; then echo; echo \$smtpsrv missing!; err_exit; fi
if [ ! $smtpport ]; then echo; echo \$smtpport missing!; err_exit; fi
if [ ! $smtpusr ]; then echo; echo \$smtpusr missing!; err_exit; fi
if [ ! $smtppwd ]; then echo; echo \$smtppwd missing!; err_exit; fi
if [ ! $mailfrom ]; then echo; echo \$mailfrom missing!; err_exit; fi

gotmsg=0
if [ "$mailto" = "" ]; then echo; echo "$0 <address>"; err_exit; else message="$( cat )"; gotmsg=1; fi

mail_input() { 
  sleep 2
  echo "helo ${HOSTNAME}" 
  echo "ehlo ${HOSTNAME}" 
  if [ $auth -eq 1 ]; then
    echo "AUTH LOGIN" 
    echo "${smtpusr}" 
    echo "${smtppwd}" 
  fi
  echo "MAIL FROM:<${mailfrom}>"
  echo "RCPT TO:<${mailto}>"
  echo "DATA"
  if [ $html -eq 1 ]; then echo "Content-type: text/html"; fi
  if [ $gotmsg -eq 0 ]; then
    echo "From: <${mailfrom}>"
    echo "To: <${mailto}>"
    echo "Subject: ${subject}"
    echo
    sleep 1
    echo "${body}"
  else
    sleep 1
    echo "$message"
  fi
  echo -e "\r\n.\r\nQUIT"
  sleep 1
} 

# You may directly send the protocol conversation via TCP 
# mail_input > /dev/tcp/$smtpsrv/$smtpport || err_exit 

# If you have nc (netcat) available in your system this 
# will offer you the protocol conversation on screen 

# mail_input | nc $smtpsrv $smtpport || err_exit 

# If on addition you have OpenSSL you can send your e-mail under TLS 

if [ $smtpport -eq 25 ]; then
  if [ $starttls -eq 0 ]; then
    # telnet
    mail_input | telnet ${smtpsrv} ${smtpport} || err_exit
  else
    mail_input | openssl s_client -starttls smtp -connect ${smtpsrv}:${smtpport} -quiet || err_exit
  fi
# TODO: test SSL 465
elif [ $smtpport -eq 465 ]; then
  mail_input | openssl s_client -connect ${smtpsrv}:${smtpport} -quiet || err_exit
elif [ $smtpport -eq 587 ]; then
  mail_input | openssl s_client -starttls smtp -connect ${smtpsrv}:${smtpport} -quiet >/dev/null 2>&1 || err_exit
fi
