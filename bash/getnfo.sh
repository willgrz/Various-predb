#!/bin/bash
#GET 1.0 (c) wm /predb.in/pre.im
#gets nfo files on commandline for use with our ZNC TCL scripts or your own
#usage: ./get.sh [NFO|SFV] [RELEASENAME] [URL]
#Static config, dont change
WHATDO=$1
RLSNAME=$2
RLSURL=$3

#Config, change
# / ARE ABSOLUTELY REQUIRED without it the script will fail
NFODIR=/home/znc/db/nfo/
SFVDIR=/home/znc/db/sfv/

#Bind IP for wget and wput
BINDIP=127.0.0.1


if [ "$WHATDO" == "NFO" ];
then
sleep 2; wget -q --no-check-certificate --timeout=3 --tries=2 --user-agent Somebot/4.0 -O $NFODIR$RLSNAME.nfo -4 --bind-address=$BINDIP $RLSURL
  SIZE=$(ls -la "$NFODIR$RLSNAME.nfo" | awk '{print $5}')
  if [ "$SIZEwer" == "0" ]; then
   echo "$RLSNAME - $NFODIR$RLSNAME.nfo" >> /home/znc/localdebug.txt
   rm $NFODIR$RLSNAME.nfo
   exit 0
   fi
cp $NFODIR$RLSNAME.nfo /var/www/nfodb/temp/$RLSNAME.nfo
fi

if [ "$WHATDO" == "SFV" ];
then
sleep 2; wget -q --no-check-certificate --timeout=3 --tries=2 --user-agent Somebot/4.0 -O $SFVDIR$RLSNAME.sfv -4 --bind-address=$BINDIP $RLSURL
  SIZE=$(ls -la "$SFVDIR$RLSNAME.sfv" | awk '{print $5}')
  if [ "$SIZEwer" == "0" ]; then
   echo "$RLSNAME - $SFVDIR$RLSNAME.sfv" >> /home/znc/localdebug.txt
   rm $SFVDIR$RLSNAME.sfv
   exit 0
   fi
cp $SFVDIR$RLSNAME.sfv /var/www/nfodb/temp/$RLSNAME.sfv
fi

if [ "$WHATDO" == "COPY" ];
then
cp $NFODIR$RLSNAME.nfo /var/www/nfodb/temp/$RLSNAME.nfo
fi
