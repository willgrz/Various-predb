#!/bin/bash
#options:
#./run.sh [run|sort||cleanall|addold|move
#dirs
rootdir=/root/archive
sfvdir=$rootdir/sfvs
nfodir=$rootdir/nfos
wwwdir=/var/www/nfodb/addnfo
olddir=$rootdir/addold
donedir=$rootdir/done
finalsfvdir=/home/znc/db/sfv
finalnfodir=/home/znc/db/nfo
 
#dont change
doarg=$1
 
 
#sort nfos, remove empty dirs etc
if [ "$doarg" == "sort" ]; then
  find -depth -type d -empty -exec rmdir {} \;
  for a in `find * -name "imdb.nfo"`; do rm $a; done
for dir in `ls | grep -v run.sh`
do cd $dir
nfocount=$(ls -l | grep -i \\.nfo | wc -l)
  if [ "$nfocount" != 1 ]; then 
    cd ..
    echo "RMING DIR $dir"
    rm -r $dir
  else
 cd ..
 fi
done
fi
 
#cleans all dirs - done,addnfo,wwwdir
if [ "$doarg" == "cleanall" ]; then
  rm -r $wwwdir/*
  rm -r $rootdir/done/*
  rm -r $rootdir/addold/*
  rm $rootdir/getold.txt
  rm $rootdir/addnfo.txt
  touch $rootdir/getold.txt
  touch $rootdir/addnfo.txt
fi
 
#cleans only localdirs, not wwwdir
if [ "$doarg" == "clean" ]; then
  rm -r $rootdir/done/*
  rm -r $rootdir/addold/*
  rm $rootdir/getold.txt
  rm $rootdir/addnfo.txt
  touch $rootdir/getold.txt
  touch $rootdir/addnfo.txt
fi
 
#moves addolded dirs, so it can be run again
if [ "$doarg" == "addold" ]; then
  mv $rootdir/addold/* $rootdir/working/
  echo "sfvs and nfos moved."
fi
 
#moves newly generated and added nfos to the target dirs
if [ "$doarg" == "move" ]; then
  mv $rootdir/sfvs/* $finalsfvdir/
  mv $rootdir/nfos/* $finalnfodir/
  echo "dirs moved, all done."
fi
 
 
#actual code for running
if [ "$doarg" == "run" ]; then
 for release in `ls | grep -v run.sh`
 do
 rlsid=$(php -f $rootdir/id.php $release)
 
  if [ "$rlsid" == 1 ]; then
 
          #getting nfo and sfv name
	   nfo=$(ls $release |grep -i \\.nfo)
	   sfv=$(ls $release |grep -i \\.sfv)
 
	  if [[ -n "$sfv" ]] ; then
	    cp $release/$sfv $sfvdir/$release.sfv
	  fi
 
	  if [[ -n "$nfo" ]] ; then
	    cp $release/$nfo $nfodir/$release.nfo
            cp $release/$nfo $wwwdir/$release.nfo
	    php -f $rootdir/update.php $release $nfo
            echo "!oldnfo $release http://url.to.nfowebdir/$release.nfo $nfo" >> $rootdir/addnfo.txt
            mv $release $donedir
	  fi
 
  elif [ "$rlsid" == 0 ]; then
  echo "!getold $release" >> $rootdir/getold.txt
  mv $release $olddir
  elif [ "$rlsid" == 2 ]; then
  rm -r $release
  fi
done
fi
