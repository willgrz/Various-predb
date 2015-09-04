#config
package require mysqltcl
package require crc32
 
#nfo announce channel
set ::filechan "#addnfochannel"
#announce channel for your !addnfo etc, usualy the same
set ::enablenfochan 1
set ::nfochan "#addnfochannel"
#relay channel, as usual partyline chans are prefixed by ~
set ::enableaddnforelay 1
set ::relaynfochan "~#pre_party"
#nfoweburl like http://nfodb.cn/rls.nfo, same format is used for SFV - change in script if needed
set ::nfoweburl "http://127.0.0.1"
set ::nfoweburlpublic "http://nfodb.predb.in"
#nfodir and sfvdir
set ::nfodir "/home/znc/db/nfo/"
set ::sfvdir "/home/znc/db/sfv/"
set ::webnfodir "/var/www/nfodb/"
#needs to be set at loading to some value, which does not matter
set ::newnforls 1
set ::oldnforls 1
set ::newsfvrls 1
set ::oldsfvrls 1
set ::newcoverrls 1
set ::addnfonickname 1
#shows -ADDNFO- etc in log window
set ::enablenfodebug 1
 
 
bind pubm   -|- *                pre:nfoget
 
 
 
proc pre:nfoget { nickname hostname handle channel arguments } {
 
        if {[string equal -nocase $channel $::filechan]} {
            set whatdo [lindex [split $arguments] 0]
 
          if {$whatdo == "!addnfo"} {
           #ignore for some nicks
           if {$nickname == "NICKNAME"} {return}
          set ::addnfonickname $nickname
          set newnfocheck [lindex [split $arguments] 1]
            if {$newnfocheck == $::newnforls} {return}
             set ::newnforls [lindex [split $arguments] 1]
             set ::newnfourl [lindex [split $arguments] 2]
             set ::newnfoname [lindex [split $arguments] 3]
              #some validity checks of URL and Name
                 if {[string match -nocase */* $::newnforls]} {return}
                 if {[string match -nocase *"* $::newnforls]} {return}
                 if {[string match -nocase *'* $::newnforls]} {return}
                 if {[string match -nocase *.sfv $::newnfoname]} {
                 return
                 }
              if { $::enablenfodebug  == 1 } { putlog "-ADDNFO- getting $::newnforls NFO from $::newnfourl (Invoked by: $nickname / $channel )" }
              if {[file isfile $::nfodir/$::newnforls.nfo]} {
                 if { $::enablenfodebug  == 1 } { putlog "-ADDNFO- $::newnforls already exists - skipping! (Invoked by: $nickname / $channel )" }
                  return
                 }
 
              #adding name and from to DB
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set filrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::newnforls' AND `nfofile` IS NULL"]  
      		mysqlclose $mysql_(handle)
       	        if { $filrel == 1 } {		
			set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `nfofile`='$::newnfoname', `nfofrom`='$::addnfonickname/Network' WHERE `release`='$::newnforls'"]
			mysqlclose $mysql_(handle) 
                  } else { return }
               #endnfotest
 
               set shit [exec /home/znc/script/Network/get.sh NFO $::newnforls $::newnfourl &]
               utimer 5 {
               if { $::enableaddnforelay  == 1 && [file isfile $::nfodir/$::newnforls.nfo] } {PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaynfochan :\!addnfo $::newnforls $::nfoweburlpublic/$::newnforls.nfo $::newnfoname"}
              }
 
            }
 
          if {$whatdo == "!addsfv"} {
          set newsfvcheck [lindex [split $arguments] 1]
            if {$newsfvcheck == $::newsfvrls} {return}
             set ::newsfvrls [lindex [split $arguments] 1]
             set ::newsfvurl [lindex [split $arguments] 2]
             set ::newsfvname [lindex [split $arguments] 3]
              #some validity checks of URL and Name
                 if {[string match -nocase */* $::newsfvrls]} {return}
                 if {[string match -nocase *"* $::newsfvrls]} {return}
                 if {[string match -nocase *'* $::newsfvrls]} {return}
              #2 CD or more SFV check, if match will NOT download sfv
                 if {[string match -nocase *.nfo $::newsfvname]} {
                 return
                 }
                 if {[string match -nocase *cd1.sfv* $::newsfvname]} {return}
                 if {[string match -nocase *cd2.sfv* $::newsfvname]} {return}
                 if {[string match -nocase *cd3.sfv* $::newsfvname]} {return}
                 if {[string match -nocase *cd4.sfv* $::newsfvname]} {return}
                 if {[string match -nocase *dvd1.sfv* $::newsfvname]} {return}
                 if {[string match -nocase *dvd2.sfv* $::newsfvname]} {return}
                 if {[string match -nocase *disc1* $::newsfvname]} {return}
                 if {[string match -nocase *disc2* $::newsfvname]} {return}
                 if {[string match -nocase *subs.sfv* $::newsfvname]} {return}
                 if {[string match -nocase *ac3.sfv* $::newsfvname]} {return}
 
              if { $::enablenfodebug  == 1 } { putlog "-ADDSFV- getting $::newsfvrls SFV from $::newsfvurl (Invoked by: $nickname / $channel )" }
              if {[file isfile $::sfvdir/$::newsfvrls.sfv]} {
                 if { $::enablenfodebug  == 1 } { putlog "-ADDSFV- $::newsfvrls already exists - skipping! (Invoked by: $nickname / $channel )" }
                  return
                 }
               set shit [exec /home/znc/script/Network/get.sh SFV $::newsfvrls $::newsfvurl &]
               utimer 5 {
               if { $::enableaddnforelay  == 1 && [file isfile $::sfvdir/$::newsfvrls.sfv] } {PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaynfochan :\!addsfv $::newsfvrls $::nfoweburlpublic/$::newsfvrls.sfv $::newsfvname"}
              }
 
            }
 
          if {$whatdo == "!oldnfo"} {
          set ::oldnfonickname $nickname
          set oldnfocheck [lindex [split $arguments] 1]
            if {$oldnfocheck == $::oldnforls} {return}
             set ::oldnforls [lindex [split $arguments] 1]
             set ::oldnfourl [lindex [split $arguments] 2]
             set ::oldnfoname [lindex [split $arguments] 3]
              #some validity checks of URL and Name
                 if {[string match -nocase */* $::oldnforls]} {return}
                 if {[string match -nocase *"* $::oldnforls]} {return}
                 if {[string match -nocase *'* $::oldnforls]} {return}
              if { $::enablenfodebug  == 1 } { putlog "-ADDOLDNFO- getting $::oldnforls NFO from $::oldnfourl (Invoked by: $nickname / $channel )" }
              if {[file isfile $::nfodir/$::oldnforls.nfo]} {
                 if { $::enablenfodebug  == 1 } { utimer 5 {putlog "-ADDOLDNFO- $::oldnforls already exists - skipping! (Invoked by: $::oldnfonickname / #addnfo )" } }
                  return
                 }
 
              #adding name and from to DB
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set filrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::oldnforls'"]  
      		mysqlclose $mysql_(handle)
       	        if { $filrel == 1 } {		
			set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `nfofile`='$::oldnfoname', `nfofrom`='$::oldnfonickname/Network' WHERE `release`='$::oldnforls'"]
			mysqlclose $mysql_(handle) 
                  } else { return }
               #endnfotest
 
               set shit [exec /home/znc/script/Network/get.sh NFO $::oldnforls $::oldnfourl &]
            }
 
          if {$whatdo == "!oldsfv"} {
           if {$nickname == "GeCube"} {return}
           if {$nickname == "pr3nup"} {return}
           if {$nickname == "twis0"} {return}
           if {$nickname == "QUiCKY"} {return}
          set ::oldsfvnickname $nickname
          set oldsfvcheck [lindex [split $arguments] 1]
            if {$oldsfvcheck == $::oldsfvrls} {return}
             set ::oldsfvrls [lindex [split $arguments] 1]
             set ::oldsfvurl [lindex [split $arguments] 2]
             set ::oldsfvname [lindex [split $arguments] 3]
              #some validity checks of URL and Name
                 if {[string match -nocase */* $::oldsfvrls]} {return}
                 if {[string match -nocase *"* $::oldsfvrls]} {return}
                 if {[string match -nocase *'* $::oldsfvrls]} {return}
              #2 CD or more SFV check, if match will NOT download sfv
                 if {[string match -nocase *cd1.sfv* $::oldsfvname]} {return}
                 if {[string match -nocase *cd2.sfv* $::oldsfvname]} {return}
                 if {[string match -nocase *cd3.sfv* $::oldsfvname]} {return}
                 if {[string match -nocase *cd4.sfv* $::oldsfvname]} {return}
                 if {[string match -nocase *dvd1.sfv* $::oldsfvname]} {return}
                 if {[string match -nocase *dvd2.sfv* $::oldsfvname]} {return}
                 if {[string match -nocase *disc1* $::oldsfvname]} {return}
                 if {[string match -nocase *disc2* $::oldsfvname]} {return}
                 if {[string match -nocase *subs.sfv* $::oldsfvname]} {return}
                 if {[string match -nocase *ac3.sfv* $::oldsfvname]} {return}
 
              if { $::enablenfodebug  == 1 } { putlog "-ADDOLDSFV- getting $::oldsfvrls SFV from $::oldsfvurl (Invoked by: $nickname / $channel )" }
              if {[file isfile $::sfvdir/$::oldsfvrls.sfv]} {
                 if { $::enablenfodebug  == 1 } { putlog "-ADDOLDSFV- $::oldsfvrls already exists - skipping! (Invoked by: $::oldsfvnickname / #addnfo )" }
                  return
                 }
               set shit [exec /home/znc/script/Network/get.sh SFV $::oldsfvrls $::oldsfvurl &]
            }
 
          if {$whatdo == "!getnfo"} {
             set ::getnforls [lindex [split $arguments] 1]
              #some validity checks of URL and Name
                 if {[string match -nocase */* $::getnforls]} {return}
                 if {[string match -nocase *"* $::getnforls]} {return}
                 if {[string match -nocase *'* $::getnforls]} {return}
               if {[file isfile $::nfodir/$::getnforls.nfo]} {
                  set ::nfocrc32 [crc::crc32 -format %08X -file $::nfodir/$::getnforls.nfo]
                     if {$::nfocrc32 == 00000000} { 
                        file delete $::nfodir/$::getnforls.nfo
                         set ::oldnforls 1
                         putquick "PRIVMSG $::nfochan :\!getnfo $::getnforls"
                        return
                     }
		    set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		     set ::getnfoname [mysqlsel $mysql_(handle) "SELECT `nfofile` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::getnforls'" -flatlist]  
      		     mysqlclose $mysql_(handle)
       	        if { [string match -nocase *\{* $::getnfoname] == 0 } { 
                   set shit [exec /home/znc/script/Network/get.sh COPY $::getnforls &]
                     if { $::enablenfochan == 1 } { utimer 1 {putquick "PRIVMSG $::nfochan :\!oldnfo $::getnforls $::nfoweburl/$::getnforls.nfo $::getnfoname $::nfocrc32" } }
             } else {
                   set shit [exec /home/znc/script/Network/get.sh COPY $::getnforls &]
                     if { $::enablenfochan == 1 } { utimer 3 {putquick "PRIVMSG $::nfochan :\!oldnfo $::getnforls $::nfoweburl/$::getnforls.nfo [string tolower $::getnforls.nfo] $::nfocrc32" } }
             }
       }
       }
       }
}
 
 
putlog "wmPRE AddNFO 1.0 by wm Loaded!"
if { $::enablenfodebug == 1} { putlog "wmPRE AddNFO DEBUG is -ON-" }
if { $::enablenfodebug == 0} { putlog "wmPRE AddNFO DEBUG is -OFF-" }
if { $::enablenfochan == 1} { putlog "wmPRE AddNFO NFO/SFV Announce is -ON- (with URL: $::nfoweburl )" }
if { $::enablenfochan == 0} { putlog "wmPRE AddNFO NFO/SFV Announce is -OFF-" }
