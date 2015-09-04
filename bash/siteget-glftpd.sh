#!/bin/bash
#now with multicd :o
#this is GLFTPd version, basically the same shit but without "-Q PRET" stuff, should work on any FTP server
#config
#dirs - local dir where NFOs should go to, needs to exist already - chmod to 777 to be sure it works
#must start and end with "/"

NFODIR=/home/znc/db/nfo/
SFVDIR=/home/znc/db/sfv/
NFOWWWDIR=/var/www/nfodb/

#dont change this
HOMEDIR=$PWD
LISTFILE=LIST$RANDOM

#url for irc announce, only thing added by the script will be /$nfoname.nfo
ADDURL=http://nfo.pre.com

#host or IP:port
FTPIP=site.host.com:1337
#login
FTPLOGIN=user
#pass - no special characters, sorry
FTPPASSWORD=password
#socks5 IP/host:port
#remove "--socks5 $FTPSOCKS5" from the curl statements if you dont use a proxy.
FTPSOCKS5=proxy.cia.gov:7331

#dont change this
FTPDIRIN=$1
FTPDIR=$FTPDIRIN/
NEWNAME=$(echo $FTPDIR|cut -d \/ -f 3)

#get dirlist
sleep 3; curl -s -S -3 -k --ftp-ssl --max-time 10 -u $FTPLOGIN:$FTPPASSWORD --list-only --socks5 $FTPSOCKS5 --max-filesize 5120000 ftp://$FTPIP$FTPDIR > $HOMEDIR/$LISTFILE
sleep 3

#single CD releases SFV, and NFO for all releases
#nfo
for found in `cat $HOMEDIR/$LISTFILE |grep \\.nfo`
 do
  echo "!sitenfo $NEWNAME $ADDURL/$NEWNAME.nfo $found"
 curl -s -S -3 -k --ftp-ssl --max-time 10 -u $FTPLOGIN:$FTPPASSWORD --socks5 $FTPSOCKS5 --max-filesize 5120000 -o "$NFODIR/$NEWNAME.nfo" ftp://$FTPIP$FTPDIR$found
 cp "$NFODIR/$NEWNAME.nfo" "$NFOWWWDIR/$NEWNAME.nfo"
 done

for found in `cat $HOMEDIR/$LISTFILE |grep \\.sfv`
 do
 curl -s -S -3 -k --ftp-ssl --max-time 10 -u $FTPLOGIN:$FTPPASSWORD --socks5 $FTPSOCKS5 --max-filesize 5120000 -o "$SFVDIR/$NEWNAME.sfv" ftp://$FTPIP$FTPDIR$found
 done

#multi CD and DVDs SFVs, will be saved as RELEASE-CD1.sfv and so on
for found in `cat $HOMEDIR/$LISTFILE |egrep -i '(CD1|CD2|CD3|CD4|CD5|DiSC1|DiSC2|DiSC3|DVD1|DVD2|DVD3)'`
 do SFVNAME=$(curl -s -3 -k --ftp-ssl --max-time 10 -u $FTPLOGIN:$FTPPASSWORD --list-only --socks5 $FTPSOCKS5 --max-filesize 5120000 ftp://$FTPIP$FTPDIR$found/ | grep \\.sfv)
 curl -s -3 -k --ftp-ssl --max-time 10 -u $FTPLOGIN:$FTPPASSWORD --socks5 $FTPSOCKS5 --max-filesize 5120000 -o "$SFVDIR/$NEWNAME-$found.sfv" ftp://$FTPIP$FTPDIR$found/$SFVNAME
 done

rm $HOMEDIR/$LISTFILE
