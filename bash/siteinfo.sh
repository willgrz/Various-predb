#!/bin/bash
#collects siteinfo
doarg=$1
ftp=$2
ftp2=$3
#no user/pass support, auth over IP or dont use a proxy
socks=127.0.0.1:33318

if [ "$ftp" == "site" ]; then
ftp=ftp://user:pass@site.com:12345/$ftp2/
doarg=dr
elif [ "$ftp" == "site2" ]; then
ftp=ftp://user:pass@site2.com:12345/$ftp2/
#you can also set another proxy here if needed
#socks=127.0.0.2:321
doarg=dr
fi


if [ "$doarg" == "gl" ]; then
#get dirlist of the dir
for subdir in `curl -s -S -3 -k --ftp-ssl --max-time 10 --list-only --socks5 $socks --max-filesize 5120000 $ftp`
 do
 #cd subdir and grep the right files together, then calculate the right size + files
  filessize=$(curl -s -S -3 -k --ftp-ssl --max-time 10 --socks5 $socks --max-filesize 5120000 $ftp$subdir/ | awk '{print $5,$9}' | egrep -i '(.r[0-9]{2}|.zip|.rar|.mkv)' | egrep -v -i '(-missing|-offline|.conflict)' | awk '{print $1}')
  #calculate files and total size
   files=$(echo "$filessize" | wc -l)
   size=$(php -f /root/siteinfo/calc.php $(($(echo $filessize | tr ' ' '+'))))

    siteinfoc=$(php -f /root/siteinfo/id2.php $subdir)
      #check 0.000 size, workaround to stop the update is setting $siteinfoc to 0, which produces an error we dont care about
      if [ "$size" == "0.000" ]; then
        echo "Wrong size on $subdir - Maybe Dir or NFO fix - skipping!"
        siteinfoc=0
      fi
    if [ "$siteinfoc" == 1 ]; then
    php -f /root/siteinfo/update.php $subdir $size $files
    echo "Updating $subdir: $files Files totaling $size MB"
    echo "!siteinfo $subdir - $files $size" >> /root/siteinfo/siteinfo.txt
    echo "!info $subdir $files $size" >> /root/siteinfo/info.txt
    else
    echo "$subdir does not exist in the DB or has siteinfo already - skipping!" >> /dev/null
    fi

 done
fi

if [ "$doarg" == "dr" ]; then
#get dirlist of the dir
for subdir in `curl -s -S -3 -k --ftp-ssl --max-time 10 -Q "PRET LIST /$ftp2/" --list-only --socks5 $socks --max-filesize 5120000 $ftp`
 do
 #cd subdir and grep the right files together, then calculate the right size + files
  filessize=$(curl -s -S -3 -k --ftp-ssl --max-time 10 -Q "PRET LIST /$ftp2/$subdir/" --socks5 $socks --max-filesize 5120000 $ftp$subdir/ | awk '{print $5,$9}' | egrep -i '(.r[0-9]{2}|.zip|.rar|.mkv)' | egrep -v -i '(-missing|-offline|.conflict)' | awk '{print $1}')
  #calculate files and total size
   files=$(echo "$filessize" | wc -l)
   size=$(php -f /root/siteinfo/calc.php $(($(echo $filessize | tr ' ' '+'))))
 
    siteinfoc=$(php -f /root/siteinfo/id2.php $subdir)
      #check 0.000 size, workaround to stop the update is setting $siteinfoc to 0, which produces an error we dont care about
      if [ "$size" == "0.000" ]; then
        echo "Wrong size on $subdir - Maybe Dir or NFO fix - skipping!"
        siteinfoc=0
      fi
    if [ "$siteinfoc" == 1 ]; then   
    php -f /root/siteinfo/update.php $subdir $size $files
    echo "Updating $subdir: $files Files totaling $size MB"
    echo "!siteinfo $subdir - $files $size" >> /root/siteinfo/siteinfo.txt
    echo "!info $subdir $files $size" >> /root/siteinfo/info.txt
    else
    echo "$subdir does not exist in the DB or has siteinfo already - skipping!" >> /dev/null
    fi
 done
fi
