# simple pre and info relay for ZNC
package require mysqltcl
set relay(author)  "wm"
set relay(version) "1.0B"
set ::rls 1
set ::frls 1
set ::grls 1
set ::delrls 1
set ::oldrls 1
set ::addprenickname 1
set ::sinforls 1
 
# Description
# This script will relay anything said on one channel to the other channel you configure
#the other channel is a ZNC partyline, so this way you can echo bots from other networks to the
#partyline and from there fill your own feed
 
# Configuration
 
# Set the nick of the bot, free usable on ZNC Partyline - if normal bot, dont use this script at all.
set ::prerelaybot PREPARTY
 
# enable relay, if 0 bot will only add to MySQL DB but not relay to other channel.
set ::enableprerelay 1
set ::enableifrelay 1
set ::enablegnrelay 1
set ::enablenukerelay 1
set ::enabledelrelay 1
set ::enablesifrelay 0
 
#enable !from in nuke channel
set ::enablefrom  0
 
#nfodirectory - can be local or mounted over sshfs or something, full path, no symlinks, no / at end
#gets loaded from addnfo.tcl
#if you dont have addnfo.tcl loaded disable !from above or edit the parts with the NFO.
 
#enable nuke-to-chan, sends [NUKE] etc. to the nuke channel
set ::enablenukechan 0
 
#enable del-to-chan, sends [DELPRE] etc. to the delpre channel
set ::enabledelchan 0
 
#enable old chan, reads and shows !addold there then
set ::enabledoldchan 1
 
# enable debug - shows -ADDPRE- -ADDNUKE- etc. in modtcl window
set ::enabledebug 0
 
# relay channel - dont forget that partyline channels are prefixed with ~
set ::relaychan "~#pre_party"
 
#nuke and delprenet, if empty at source
set ::globalnukenet NUKENET
set ::globaldelnet NUKENET
 
# from channels, to disable one just set it to #deadbeef or some channel were the bot is not in
#usualy the nuke channel
set ::fromchan "#nuke"
#other channels. self explanatory
set ::nukechan "#nuke"
set ::addoldchan "#old"
set ::infochan "#info"
set ::delprechan "#delpre"
set ::siteinfochan "#siteinfo"
 
# Map for section replacements - beware about the bad TCL mapper:
#Syntax is: <input> <output> as example: TV-SK TV if input in TV-SK, output will be TV.
#If you set: DVDRIP XVID TV-DVDRIP TV
#then input "TV-DVDRIP" will match at "DVDRIP" and the output will be "XVID" instead of "TV"
#so read carefully through the docs of "string map" or find another way to map them
#
set ::sectionmap "BDRIP-TV TV WEB-MUSIC MP3 TV-DVDRIP TV DVDRIP-TV TV X264-MOVIES X264 MUSIC-LIVESET MP3 SAMPLES APPS PC-GAMES GAMES M-DVDR MDVDR DVDRNL DVDR DVDR-TV DVDR DVDR-SERIES-MULTI DVDR DVD-R DVDR DIVX XVID Crap PRE CHARTS MP3 0DAY-DE 0DAY AUDIOBOOK MP3 DVDRIP XVID x264-ger X264-DE DVDR-PAL DVDR SUBPACK PRE MOVIE-DVDR DVDR ABOOK MP3 xvid_de-pre XVID-DE SUBS PRE BOOKWARE APPS TV-NONENGLISH TV HD-X264 X264 720P-DE X264-DE MUSIC-VIDEO MVID VC1 X264 BDR-WMV X264 xbox XBOX360 X360 XBOX360 ps2 PS3 ngc WII BLURAY X264 PDA 0DAY 0-Day 0DAY TV-X264 TV-HD TV-XVID TV MOVIE-X264 X264 HDTV TV-HD fear MP3 HDTV-X264 TV-HD TV-DVDR DVDR HDDVD X264 UNKNOWN PRE TV-BDRIP TV COVERS PRE COVER PRE apps APPS MOVIE-XVID XVID BDRIP X264 DVDR-MUSIC MDVDR GER-XViD XVID"
 
#Mysql Info
set ::amysqlhost 127.0.0.1
set ::amysqluser LOGIN
set ::amysqlpass PASSWORD
set ::themysqldb DATABASE
 
bind pubm   -|- *                pre:relay
 
 
proc pre:relay { nickname hostname handle channel arguments } {
	if {[string equal -nocase $channel $::fromchan] || [string equal -nocase $channel $::infochan]} {
         set whatdo [lindex [split $arguments] 0]
 
         if {$whatdo == "!addpre" || $whatdo == "!add"} {
         #ignore some nicks
        if {$nickname == "NICKNAME1" || $nickname == "NICKNAME2"} {return}
         set precheck [mysqlescape [lindex [split $arguments] 1]]
         if {$precheck == $::rls} {return}
         set ::rls [mysqlescape [lindex [split $arguments] 1]]
         set cat [mysqlescape [lindex [split $arguments] 2]]
         if { $cat == "" } {return}
         if { $::rls == "" } {return}
         set ::addprenickname [mysqlescape $nickname]
         #some (bad) spam filters
           if {[string match -nocase *.shibby.* $::rls]} { putlog "$:::rls triggered the Spamfilter!"}
           if {[string match -nocase *.P2L.* $::rls]} { putlog "$::rls triggered the Spamfilter!"}
           if {[string match -nocase *.niggahs.* $::rls]} { putlog "$::rls triggered the Spamfilter!"}
           if {[string match -nocase *.echo.channel* $::rls]} { putlog "$::rls triggered the Spamfilter!"}
           if {[string match -nocase *.OVH.* $::rls]} { putlog "$::rls triggered the Spamfilter!"}
           if {[string match -nocase *.i3d.* $::rls]} { putlog "$::rls triggered the Spamfilter!"}
           if {[string match -nocase *-LOL_* $::rls]} { putlog "$::rls triggered the Spamfilter!"}
           if {[string match -nocase *.p2p.* $::rls]} { putlog "$::rls triggered the Spamfilter!"}
           if {[string match *NUKED* $::rls]} {return}
           if {[string match -nocase */* $::rls]} {return}
           if {[string match -nocase *%* $::rls]} {return}
              #this should work on 99% of the releases
              set group [lindex [split "$::rls" "-"] end]
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set numrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::rls'"]                         
      		mysqlclose $mysql_(handle)
       	        if { $numrel == 0 } {		
			set time [clock seconds]
                     set cat [string map -nocase $::sectionmap $cat]
                       if {[string match -nocase *.S??E??.* $::rls] || [string match -nocase *.E??.* $::rls]} {set cat TV}
                       if {[string match -nocase *.ebook* $::rls]} {set cat EBOOK}
                       if {[string match -nocase *.ANIME.* $::rls]} {set cat ANIME}
                       if {[string match -nocase *PS3* $::rls]} {set cat PS3}
                       if {[string equal -nocase EBOOK $cat] && [string match -nocase *german* $::rls]} {set cat EBOOK-DE}
                       if {[string equal -nocase $cat mp3] && [string match -nocase *_INT $::rls]} {set cat MP3-INTERNAL}
                       if {[string equal -nocase $cat X264] && [string match -nocase *xvid* $::rls]} {set cat XVID}
                       if {[string equal -nocase $cat mp3] && [string match -nocase *x264* $::rls]} {set cat MVID}
                       if {[string match -nocase *p.HDTV.X264* $::rls]} {set cat TV-HD}
                       if {[string match -nocase TV* $cat] && [string match -nocase *BluRay.X264* $::rls]} {set cat TV-HD}
                       if {[string match -nocase TV* $cat] && [string match -nocase *german* $::rls]} {set cat $cat-DE}
                       if {[string equal -nocase XVID $cat] && [string match -nocase *german* $::rls] && [string match -nocase *xvid* $::rls]} {set cat XVID-DE}
                       if {[string equal -nocase DVDR $cat] && [string match -nocase *german* $::rls] && [string match -nocase *DVDR* $::rls]} {set cat DVDR-DE}
                       if {[string equal -nocase X264 $cat] && [string match -nocase *german* $::rls] && [string match -nocase *X264* $::rls]} {set cat X264-DE}
                       if {[string match -nocase *XXX* $::rls]} {set cat XXX}
                       if {[string equal -nocase MV $cat]} {set cat MVID}
                       if {[string equal -nocase - $cat]} {set cat MP3}
                       if {[string equal -nocase GAME $cat]} {set cat GAMES}
                       if {[string equal -nocase BD $cat]} {set cat X264}
                       if {[string equal -nocase BDR $cat]} {set cat X264}
                       if {[string equal -nocase MUSIC $cat]} {set cat MP3}
                       if {[string match -nocase *imageset* $::rls]} {set cat IMAGESET}
                       if {[string match -nocase *doku* $::rls]} {set cat DOKU}
                       if {[string equal -nocase TV-HD-DE $cat] && [string match -nocase *-SoW $::rls]} {set cat X264-DE}
                       if {[string equal -nocase TV-HD-DE $cat] && [string match -nocase *-ENCOUNTERS $::rls]} {set cat X264-DE}
                       if {[string equal -nocase TV-HD-DE $cat] && [string match -nocase *-DECENT $::rls]} {set cat X264-DE}
                       set cat [string toupper $cat]
			set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			set nix [mysqlexec $mysql_(handle) "INSERT INTO `02b67c3eae678dc49209d6de4709a171` (`time`,`section`,`release`,`prefrom`,`group`) VALUES ('$time', '$cat', '$::rls', '$::addprenickname/Network', '$group')"]	
                     if { $::enableprerelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!addpre $::rls $cat" }
			if { $::enabledebug  == 1 } { putlog "-ADDPRE- $cat / $time / $::rls successfully added (Invoked by: $nickname / $channel )" }
                      mysqlclose $mysql_(handle) 
		}
         }
 
         if {$whatdo == "!info"} {
         #ignore some nicks
        if {$nickname == "NICKNAME1" || $nickname == "NICKNAME2"} {return}
         set icheck [mysqlescape [lindex [split $arguments] 1]]
         if {$icheck == $::frls} {return}
         set ::frls [mysqlescape [lindex [split $arguments] 1]]
         set files [mysqlescape [lindex [split $arguments] 2]]
         set size [mysqlescape [lindex [split $arguments] 3]]
         if { $files == "" } {return}
         if { $files == "0" } {return}
         if { $files == "-" } {return}
         if { $size == "" } {return}
         if { $size == "0" } {return}
         if { $size == "-" } {return}
         if {$files >= 5 && $size <= 3} {return}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set filrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::frls' AND `size` = 0"]  
      		mysqlclose $mysql_(handle)
       	        if { $filrel == 1 } {		
			set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `files`='$files', `size`='$size' WHERE `release`='$::frls'"]	
                     if { $::enableifrelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!info $::frls $files $size" }
			if { $::enabledebug  == 1 } { putlog "-ADDINFO- $files F / $size MB on $::frls (Invoked by: $nickname / $channel )" }
			mysqlclose $mysql_(handle) 
                  }
		}
 
         if {$whatdo == "!genre" || $whatdo == "!gn"} {
         #Genre produces high server load, so accept only some whitelisted, good bots.
        if {$nickname == "A" || $nickname == "B" || $nickname == "C"} {
         set gcheck [mysqlescape [lindex [split $arguments] 1]]
         if {$gcheck == $::grls} {return}
         set ::grls [mysqlescape [lindex [split $arguments] 1]]
         set genre [mysqlescape [lindex [split $arguments] 2]]
          #if {[string match -nocase *'* $genre]} {return}
          #if {[string match -nocase *'* $genre]} {return}
          #if {[string match -nocase *"* $genre]} {return}
          if {[string match -nocase */* $genre]} {return}
          if { $genre == "" } {return}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set genrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::grls' AND `genre` = ''"] 
      		mysqlclose $mysql_(handle)
       	        if { $genrel == 1 } {		
			set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `genre`='$genre' WHERE `release`='$::grls'"]	
                     if { $::enablegnrelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!genre $::grls $genre" }
			if { $::enabledebug  == 1 } { putlog "-ADDGENRE- $genre on $::grls (Invoked by: $nickname / $channel )" }
			mysqlclose $mysql_(handle) 
                 }
		}
          }
 
       }
 
     if {[string equal -nocase $channel $::siteinfochan]} {
      set whatinfo [lindex [split $arguments] 0]
 
         if {$whatinfo == "!siteinfo" || $whatinfo == "!ginfo" || $whatinfo == "!exactinfo"} {
        if {$nickname == "NICKNAME"} {return}
         set sicheck [mysqlescape [lindex [split $arguments] 1]]
         if {$sicheck == $::sinforls} {return}
         set ::sinforls [mysqlescape [lindex [split $arguments] 1]]
         set sinfofiles [mysqlescape [lindex [split $arguments] 3]]
         set sinfosize [mysqlescape [lindex [split $arguments] 4]]
         if { $sinfofiles == "" } {return}
         if { $sinfofiles == "0" } {return}
         if { $sinfofiles == "-" } {return}
         if { $sinfosize == "" } {return}
         if { $sinfosize == "0" } {return}
         if { $sinfosize == "-" } {return}
         if {$sinfofiles >= 5 && $sinfosize <= 3} {return}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set sfilrel [mysqlsel $mysql_(handle) "SELECT `size`, `files` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::sinforls'" -flatlist]  
		mysqlclose $mysql_(handle)
               if { $sfilrel != "" } {
			set ssqlsize [mysqlescape [lindex [split $sfilrel] 0]]
			set ssqlfiles [mysqlescape [lindex [split $sfilrel] 1]]
			} else {
			return
			}
		set snew_length [string length $sinfosize]
		set sold_length [string length $ssqlsize]
			#putlog "$sinfosize / $snew_length - $ssqlsize / $sold_length"
		 if {$snew_length > $sold_length} {
			#putlog "new size is better"
			#putlog "$::sinforls New: S $sinfosize F $sinfofiles - Old: S $ssqlsize F $ssqlfiles"
			set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `files`='$sinfofiles', `size`='$sinfosize', `siteinfo`='1' WHERE `release`='$::sinforls'"]
			mysqlclose $mysql_(handle)
                     if { $::enablesifrelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!info $::sinforls $sinfofiles $sinfosize" }
			if { $::enabledebug  == 1 } { putlog "-ADDSITEINFO- $sinfofiles F / $sinfosize MB on $::sinforls (Invoked by: $nickname / $channel )" }
			} else {
			#putlog "old size is better"
			return
			}
		}
}
 
     if {[string equal -nocase $channel $::nukechan]} {
      set whatnuke [lindex [split $arguments] 0]
      set whatdo [lindex [split $arguments] 1]
 
       if {$whatnuke == "\[\00304NUKE\003\]" || $whatnuke == "\[\0034NUKE\003\]" || $whatnuke == "\[\00304nuke\003\]" || $whatnuke == "\[\0034nuke\003\]"} {
         if {$whatdo == "!nuke"} {
         set nukerls [mysqlescape [lindex [split $arguments] 2]]
         set reason [mysqlescape [lindex [split $arguments] 3]]
         set nukenet [mysqlescape [lindex [split $arguments] 4]]
           if {$nukenet == "Sheep"} {return}
           if {$nukenet == "SanctityDenied"} {return}
         if { [string is integer -strict $reason] } {return}
              set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::nukerel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::nukerel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isdupe [mysqlsel $mysql_(handle) "SELECT `nukeid` FROM `b8e2e0e422cae4838fb788c891afb44f` WHERE `releaseid` = '$::nukerel' AND `reason` = '$reason'"]
                       mysqlclose $mysql_(handle)
                       if { $isdupe != 0 } { 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset isdupe
                        unset ::nukerel
                       } else {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isnuked`='1' WHERE `release`='$nukerls'"]
                       set nuketime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `b8e2e0e422cae4838fb788c891afb44f` (`releaseid`,`time`,`reason`,`network`) VALUES ('$::nukerel', '$nuketime', '$reason', '$nukenet')"]	
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\[\00304NUKE\003\] !nuke $nukerls $reason $nukenet" }
                       if { $::enablenukerelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!nuke $nukerls $reason $nukenet" }
			  if { $::enabledebug  == 1 } { putlog "-ADDNUKE- $reason from $nukenet on $nukerls (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset ::nukerel
		}
           }
        }
      }
 
       if {$whatnuke == "\[\00304MODNUKE\003\]" || $whatnuke == "\[\0034MODNUKE\003\]" || $whatnuke == "\[\00304modnuke\003\]" || $whatnuke == "\[\0034modnuke\003\]"} {
         if {$whatdo == "!modnuke"} {
         set nukerls [mysqlescape [lindex [split $arguments] 2]]
         set reason [mysqlescape [lindex [split $arguments] 3]]
         set nukenet [mysqlescape [lindex [split $arguments] 4]]
           if {$nukenet == "Sheep"} {return}
           if {$nukenet == "SanctityDenied"} {return}
         if { [string is integer -strict $reason] } {return}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::nukerel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::nukerel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isdupe [mysqlsel $mysql_(handle) "SELECT `nukeid` FROM `b8e2e0e422cae4838fb788c891afb44f` WHERE `releaseid` = '$::nukerel' AND `reason` = '$reason'"]
                       mysqlclose $mysql_(handle)
                       if { $isdupe != 0 } { 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset isdupe
                        unset ::nukerel
                       } else {	
                        set nuketime [clock seconds]
                        set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                        set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isnuked`='1' WHERE `release`='$nukerls'"]
                        set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                        set nix [mysqlexec $mysql_(handle) "INSERT INTO `b8e2e0e422cae4838fb788c891afb44f` (`releaseid`,`time`,`reason`,`network`,`ismodnuke`) VALUES ('$::nukerel', '$nuketime', '$reason', '$nukenet', '1')"]	
                        if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\[\00304MODNUKE\003\] !modnuke $nukerls $reason $nukenet" }
                        if { $::enablenukerelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!modnuke $nukerls $reason $nukenet" }
			   if { $::enabledebug  == 1 } { putlog "-ADDMODNUKE- $reason from $nukenet on $nukerls (Invoked by: $nickname / $channel )" }
			   mysqlclose $mysql_(handle) 
                         unset nukerls
                         unset reason
                         unset nukenet
                        unset ::nukerel
		}
           }
        }
      }
 
       if {$whatnuke == "\[\00303UNNUKE\003\]" || $whatnuke == "\[\0033UNNUKE\003\]" || $whatnuke == "\[\00303unnuke\003\]" || $whatnuke == "\[\0033unnuke\003\]"} {
         if {$whatdo == "!unnuke"} {
         set nukerls [mysqlescape [lindex [split $arguments] 2]]
         set reason [mysqlescape [lindex [split $arguments] 3]]
         set nukenet [mysqlescape [lindex [split $arguments] 4]]
           if {$nukenet == "Sheep"} {return}
           if {$nukenet == "SanctityDenied"} {return}
         if { [string is integer -strict $reason] } {return}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::nukerel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::nukerel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isdupe [mysqlsel $mysql_(handle) "SELECT `nukeid` FROM `b8e2e0e422cae4838fb788c891afb44f` WHERE `releaseid` = '$::nukerel' AND `reason` = '$reason'"]
                       mysqlclose $mysql_(handle)
                       if { $isdupe != 0 } { 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset isdupe
                        unset ::nukerel
                       } else {		
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isnuked`='0' WHERE `release`='$nukerls'"]	
                       set nuketime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `b8e2e0e422cae4838fb788c891afb44f` (`releaseid`,`time`,`reason`,`network`,`isnuke`) VALUES ('$::nukerel', '$nuketime', '$reason', '$nukenet', '0')"]	
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\[\00303UNNUKE\003\] !unnuke $nukerls $reason $nukenet" }
                       if { $::enablenukerelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!unnuke $nukerls $reason $nukenet" }
			  if { $::enabledebug  == 1 } { putlog "-ADDUNNUKE- $reason from $nukenet on $nukerls (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset ::nukerel
 		}
            }
          }
        }
 
       if {$whatnuke == "!nuke"} {
         set nukerls [mysqlescape [lindex [split $arguments] 1]]
         set reason [mysqlescape [lindex [split $arguments] 2]]
         set nukenet [mysqlescape [lindex [split $arguments] 3]]
           if {$nukenet == "Sheep"} {return}
           if {$nukenet == "SanctityDenied"} {return}
         if { [string is integer -strict $reason] } {return}
         if { $nukenet == "" } {set nukenet $::globalnukenet}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::nukerel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::nukerel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isnuked [mysqlsel $mysql_(handle) "SELECT `isnuked` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
                       mysqlclose $mysql_(handle)
                       if { $isnuked == 1 } { 
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\ $nukerls is already nuked - not doing anything" }
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset ::nukerel
                       } else {
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isnuked`='1' WHERE `release`='$nukerls'"]	
                       set nuketime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `b8e2e0e422cae4838fb788c891afb44f` (`releaseid`,`time`,`reason`,`network`) VALUES ('$::nukerel', '$nuketime', '$reason', '$nukenet')"]	
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\[\00304NUKE\003\] !nuke $nukerls $reason $nukenet" }
                       if { $::enablenukerelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!nuke $nukerls $reason $nukenet" }
			  if { $::enabledebug  == 1 } { putlog "-ADDNUKE- $reason from $nukenet on $nukerls (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset isnuked
                        unset ::nukerel
		}
            }
          }
 
       if {$whatnuke == "!modnuke"} {
         set nukerls [mysqlescape [lindex [split $arguments] 1]]
         set reason [mysqlescape [lindex [split $arguments] 2]]
         set nukenet [mysqlescape [lindex [split $arguments] 3]]
           if {$nukenet == "Sheep"} {return}
           if {$nukenet == "SanctityDenied"} {return}
         if { [string is integer -strict $reason] } {return}
         if { $nukenet == "" } {set nukenet $::globalnukenet}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::nukerel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::nukerel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isdupe [mysqlsel $mysql_(handle) "SELECT `nukeid` FROM `b8e2e0e422cae4838fb788c891afb44f` WHERE `releaseid` = '$::nukerel' AND `reason` = '$reason'"]
                       mysqlclose $mysql_(handle)
                       if { $isdupe != 0 } { 
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\ $nukerls is already nuked with the same reason - not doing anything" }
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset isdupe
                        unset ::nukerel
                       } else {	
                       set nuketime [clock seconds]
                       set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isnuked`='1' WHERE `release`='$nukerls'"]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `b8e2e0e422cae4838fb788c891afb44f` (`releaseid`,`time`,`reason`,`network`,`ismodnuke`) VALUES ('$::nukerel', '$nuketime', '$reason', '$nukenet', '1')"]	
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\[\00304MODNUKE\003\] !modnuke $nukerls $reason $nukenet" }
                       if { $::enablenukerelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!modnuke $nukerls $reason $nukenet" }
			  if { $::enabledebug  == 1 } { putlog "-ADDMODNUKE- $reason from $nukenet on $nukerls (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset ::nukerel
		}
            }
          }
 
       if {$whatnuke == "!unnuke"} {
         set nukerls [mysqlescape [lindex [split $arguments] 1]]
         set reason [mysqlescape [lindex [split $arguments] 2]]
         set nukenet [mysqlescape [lindex [split $arguments] 3]]
           #this ignores some banned networks at echo in, remove if you want
           if {$nukenet == "Sheep"} {return}
           if {$nukenet == "SanctityDenied"} {return}
         if { [string is integer -strict $reason] } {return}
         if { $nukenet == "" } {set nukenet $::globalnukenet}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::nukerel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::nukerel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isnuked [mysqlsel $mysql_(handle) "SELECT `isnuked` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$nukerls'" -flatlist]
                       if { $isnuked == 0 } { 
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\ $nukerls is not nuked - not doing anything" }
                        unset nukerls
                        unset reason
                        unset nukenet
                       } else {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isnuked`='0' WHERE `release`='$nukerls'"]	
                       set nuketime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `b8e2e0e422cae4838fb788c891afb44f` (`releaseid`,`time`,`reason`,`network`,`isnuke`) VALUES ('$::nukerel', '$nuketime', '$reason', '$nukenet', '0')"]	
                       if { $::enablenukechan  == 1 } { putquick "PRIVMSG $::nukechan :\[\00303UNNUKE\003\] !unnuke $nukerls $reason $nukenet" }
                       if { $::enablenukerelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!unnuke $nukerls $reason $nukenet" }
			  if { $::enabledebug  == 1 } { putlog "-ADDUNNUKE- $reason from $nukenet on $nukerls (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset nukerls
                        unset reason
                        unset nukenet
                        unset isnuked
                        unset ::nukerel
		}
            }
          }
 
       if {$whatnuke == "!afrom" || $whatnuke == "!from"} {
         set fromrls [mysqlescape [lindex [split $arguments] 1]]
            set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
            set fromsql [mysqlsel $mysql_(handle) "SELECT `time`, `prefrom`, `nfofrom`, `release`, `nfofile`  FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$fromrls'" -flatlist]
            mysqlclose $mysql_(handle)
               if { $fromsql != "" } {
                set fromtime [mysqlescape [lindex [split $fromsql] 0]]
                   set fromtimeformated [clock format $fromtime -format {%Y-%m-%d %H:%M:%S}]
                set frompre [mysqlescape [lindex [split $fromsql] 1]]
                set fromnfo [mysqlescape [lindex [split $fromsql] 2]]
                   putlog $fromnfo
                set rlsfrom [mysqlescape [lindex [split $fromsql] 3]]
                set nfoname [mysqlescape [lindex [split $fromsql] 4]]
                   putlog $nfoname
                 if {[string match -nocase \{\} $rlsfrom] == 0} {
                    if { $::enablefrom  == 1 } { putquick "PRIVMSG $::nukechan :\ $frompre $fromtime $fromtimeformated GMT" }
                    }
                 if {[string match -nocase \{\} $fromnfo] == 0} {
                    if { $nfoname == "" } { set nfoname unknown }
                   if {[string match -nocase */SITE $fromnfo]} { set fromnfo SITE }
                   if { $::enablefrom  == 1 } { putquick "PRIVMSG $::nukechan :\ $rlsfrom $fromnfo $nfoname" }
                   }
                 }
               }
 
        }
 
     if {[string equal -nocase $channel $::delprechan]} {
      set whatdel [lindex [split $arguments] 0]
      set whatdo [lindex [split $arguments] 1]
 
       if {$whatdel == "\[\00304DELPRE\003\]" || $whatdel == "\[\0034DELPRE\003\]"} {
         if {$whatdo == "!delpre"} {
         set delcheck [mysqlescape [lindex [split $arguments] 2]]
         if {$delcheck == $::delrls} {return}
         set ::delrls    [mysqlescape [lindex [split $arguments] 2]]
         set delreason [mysqlescape [lindex [split $arguments] 3]]
         set delnet    [mysqlescape [lindex [split $arguments] 4]]
              set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::delrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::delrls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::delrel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set delisdupe [mysqlsel $mysql_(handle) "SELECT `deleteid` FROM `19503eb6973fcbf266ed3c3faada235e` WHERE `releaseid` = '$::delrel' AND `reason` = '$delreason'"]
                       mysqlclose $mysql_(handle)
                       if { $delisdupe != 0 } { 
                        unset delreason
                        unset delnet
                        unset delisdupe
                        unset ::delrel
                       } else {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isdeleted`='1' WHERE `release`='$::delrls'"]
                       set deltime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `19503eb6973fcbf266ed3c3faada235e` (`releaseid`,`time`,`reason`,`network`,`isdeleted`) VALUES ('$::delrel', '$deltime', '$delreason', '$delnet', '1')"]	
                       if { $::enabledelchan  == 1 } { putquick "PRIVMSG $::delprechan :\[\00304DELPRE\003\] !delpre $::delrls $delreason $delnet" }
                       if { $::enabledelrelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!delpre $::delrls $delreason $delnet" }
			  if { $::enabledebug  == 1 } { putlog "-DELPRE- $::delrls from $delnet with $delreason (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset delreason
                        unset delnet
                        unset delisdupe
                        unset ::delrel
		}
           }
        }
      }
 
 
       if {$whatdel == "\[\00303UNDELPRE\003\]" || $whatdel == "\[\0033UNDELPRE\003\]"} {
         if {$whatdo == "!undelpre"} {
         set delcheck [mysqlescape [lindex [split $arguments] 2]]
         if {$delcheck == $::delrls} {return}
         set ::delrls    [mysqlescape [lindex [split $arguments] 2]]
         set delreason [mysqlescape [lindex [split $arguments] 3]]
         set delnet    [mysqlescape [lindex [split $arguments] 4]]
              set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::delrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::delrls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::delrel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set delisdupe [mysqlsel $mysql_(handle) "SELECT `deleteid` FROM `19503eb6973fcbf266ed3c3faada235e` WHERE `releaseid` = '$::delrel' AND `reason` = '$delreason'"]
                       mysqlclose $mysql_(handle)
                       if { $delisdupe != 0 } { 
                        unset delreason
                        unset delnet
                        unset delisdupe
                        unset ::delrel
                       } else {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isdeleted`='0' WHERE `release`='$::delrls'"]
                       set deltime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `19503eb6973fcbf266ed3c3faada235e` (`releaseid`,`time`,`reason`,`network`,`isdeleted`) VALUES ('$::delrel', '$deltime', '$delreason', '$delnet', '0')"]	
                       if { $::enabledelchan  == 1 } { putquick "PRIVMSG $::delprechan :\[\00303UNDELPRE\003\] !undelpre $::delrls $delreason $delnet" }
                       if { $::enabledelrelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!undelpre $::delrls $delreason $delnet" }
			  if { $::enabledebug  == 1 } { putlog "-UNDELPRE- $::delrls from $delnet with $delreason (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset delreason
                        unset delnet
                        unset delisdupe
                        unset ::delrel
		}
           }
        }
      }
 
       if {$whatdel == "!delpre"} {
         set delcheck [mysqlescape [lindex [split $arguments] 1]]
         if {$delcheck == $::delrls} {return}
         set ::delrls [mysqlescape [lindex [split $arguments] 1]]
         set delreason [mysqlescape [lindex [split $arguments] 2]]
         set delnet [mysqlescape [lindex [split $arguments] 3]]
         if { $delnet == "" } {set delnet $::globaldelnet}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::delrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::delrls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::delrel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isdelpred [mysqlsel $mysql_(handle) "SELECT `isdeleted` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::delrls'" -flatlist]
                       mysqlclose $mysql_(handle)
                       if { $isdelpred == 1 } { 
                        unset delreason
                        unset delnet
                        unset isdelpred
                        unset ::delrel
                       } else {
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isdeleted`='1' WHERE `release`='$::delrls'"]	
                       set deltime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `19503eb6973fcbf266ed3c3faada235e` (`releaseid`,`time`,`reason`,`network`,`isdeleted`) VALUES ('$::delrel', '$deltime', '$delreason', '$delnet', '1')"]	
                       if { $::enabledelchan  == 1 } { putquick "PRIVMSG $::delprechan :\[\00304DELPRE\003\] !delpre $::delrls $delreason $delnet" }
                       if { $::enabledelrelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!delpre $::delrls $delreason $delnet" }
                       if { $::enabledebug  == 1 } { putlog "-DELPRE- $::delrls from $delnet with $delreason (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset delreason
                        unset delnet
                        unset isdelpred
                        unset ::delrel
		}
            }
          }
 
 
       if {$whatdel == "!undelpre"} {
         set delcheck [mysqlescape [lindex [split $arguments] 1]]
         if {$delcheck == $::delrls} {return}
         set ::delrls [mysqlescape [lindex [split $arguments] 1]]
         set delreason [mysqlescape [lindex [split $arguments] 2]]
         set delnet [mysqlescape [lindex [split $arguments] 3]]
         if { $delnet == "" } {set delnet $::globaldelnet}
		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		set ::delrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::delrls'" -flatlist]
      		mysqlclose $mysql_(handle)
       	        if { $::delrel != 0 } {	
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                       set isdelpred [mysqlsel $mysql_(handle) "SELECT `isdeleted` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::delrls'" -flatlist]
                       mysqlclose $mysql_(handle)
                       if { $isdelpred == 0 } { 
                        unset delreason
                        unset delnet
                        unset isdelpred
                        unset ::delrel
                       } else {
			  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
			  set update [mysqlexec $mysql_(handle) "UPDATE `02b67c3eae678dc49209d6de4709a171` SET `isdeleted`='0' WHERE `release`='$::delrls'"]	
                       set deltime [clock seconds]
                       set nix [mysqlexec $mysql_(handle) "INSERT INTO `19503eb6973fcbf266ed3c3faada235e` (`releaseid`,`time`,`reason`,`network`,`isdeleted`) VALUES ('$::delrel', '$deltime', '$delreason', '$delnet', '0')"]	
                       if { $::enabledelchan  == 1 } { putquick "PRIVMSG $::delprechan :\[\00303UNDELPRE\003\] !undelpre $delrls $delreason $delnet" }
                       if { $::enabledelrelay  == 1 } { PutAllUser ":$::prerelaybot![getchanhost $::prerelaybot] PRIVMSG $::relaychan :\!undelpre $::delrls $delreason $delnet" }
                       if { $::enabledebug  == 1 } { putlog "-UNDELPRE- $::delrls from $delnet with $delreason (Invoked by: $nickname / $channel )" }
			  mysqlclose $mysql_(handle) 
                        unset delreason
                        unset delnet
                        unset isdelpred
                        unset ::delrel
		}
            }
          }
        }
 
     if {[string equal -nocase $channel $::addoldchan]} {
         set whatold [lindex [split $arguments] 0]
 
       if {$whatold == "!addold"} {
         set oldcheck [mysqlescape [lindex [split $arguments] 1]]
         if {$oldcheck == $::oldrls} {return}
         set ::oldrls [mysqlescape [lindex [split $arguments] 1]]
         set oldcat   [mysqlescape [lindex [split $arguments] 2]]
         set oldtime  [mysqlescape [lindex [split $arguments] 3]]
         set actualtime [clock seconds]
         set oldfiles [mysqlescape [lindex [split $arguments] 4]]
         set oldsize  [mysqlescape [lindex [split $arguments] 5]]
         set oldgenre [mysqlescape [lindex [split $arguments] 6]]
         set ::addoldnickname [mysqlescape $nickname]
          if { $::oldrls == "-" } {return}
          if {[string match *NUKED* $::rls]} {return}
          if {[string match -nocase */* $::rls]} {return}
          if {[string match -nocase *%* $::rls]} {return}
             if {[expr $oldtime > $actualtime]} { 
                if { $::enabledoldchan  == 1 } { putquick "PRIVMSG $::addoldchan :\ $::addoldnickname seems to have wrong add time! Time given: $oldtime - My Time: $actualtime" }
                set ::oldrls 1
                return
             } else {
         set oldgroup [lindex [split "$::oldrls" "-"] end]
          if { $oldfiles == "-" } {set oldfiles "0"}
          if { $oldsize == "-" } {set oldsize "0"}
          if { $oldgenre == "-" } {set oldgenre ""}
          		set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
		          set oldnumrel [mysqlsel $mysql_(handle) "SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$::oldrls'"]                         
      		     mysqlclose $mysql_(handle)
       	        if { $oldnumrel == 0 } {		
                       set oldcat [string map -nocase $::sectionmap $oldcat]
                       if {[string match -nocase *.S??E??.* $::oldrls] || [string match -nocase *.E??.* $::oldrls]} {set oldcat TV}
                       if {[string match -nocase *.ebook* $::oldrls]} {set oldcat EBOOK}
                       if {[string match -nocase *.ANIME.* $::oldrls]} {set oldcat ANIME}
                       if {[string match -nocase *PS3* $::oldrls]} {set oldcat PS3}
                       if {[string equal -nocase EBOOK $oldcat] && [string match -nocase *german* $::oldrls]} {set oldcat EBOOK-DE}
                       if {[string equal -nocase $oldcat mp3] && [string match -nocase *_INT $::oldrls]} {set oldcat MP3-INTERNAL}
                       if {[string equal -nocase $oldcat X264] && [string match -nocase *xvid* $::oldrls]} {set oldcat XVID}
                       if {[string equal -nocase $oldcat mp3] && [string match -nocase *x264* $::oldrls]} {set oldcat MVID}
                       if {[string match -nocase *p.HDTV.X264* $::oldrls]} {set oldcat TV-HD}
                       if {[string match -nocase TV* $oldcat] && [string match -nocase *BluRay.X264* $::oldrls]} {set oldcat TV-HD}
                       if {[string match -nocase TV* $oldcat] && [string match -nocase *german* $::oldrls]} {set oldcat $oldcat-DE}
                       if {[string equal -nocase XVID $oldcat] && [string match -nocase *german* $::oldrls] && [string match -nocase *xvid* $::oldrls]} {set oldcat XVID-DE}
                       if {[string equal -nocase DVDR $oldcat] && [string match -nocase *german* $::oldrls] && [string match -nocase *DVDR* $::oldrls]} {set oldcat DVDR-DE}
                       if {[string equal -nocase X264 $oldcat] && [string match -nocase *german* $::oldrls] && [string match -nocase *X264* $::oldrls]} {set oldcat X264-DE}
                       if {[string match -nocase *XXX* $::oldrls]} {set oldcat XXX}
                       if {[string equal -nocase MV $oldcat]} {set oldcat MVID}
                       if {[string equal -nocase - $oldcat]} {set oldcat MP3}
                       if {[string equal -nocase GAME $oldcat]} {set oldcat GAMES}
                       if {[string equal -nocase BD $oldcat]} {set oldcat X264}
                       if {[string equal -nocase BDR $oldcat]} {set oldcat X264}
                       if {[string equal -nocase MUSIC $oldcat]} {set oldcat MP3}
                       if {[string match -nocase *imageset* $::oldrls]} {set oldcat IMAGESET}
                       if {[string match -nocase *doku* $::oldrls]} {set oldcat DOKU}
                       if {[string equal -nocase TV-HD-DE $oldcat] && [string match -nocase *-SoW $::oldrls]} {set oldcat X264-DE}
                       if {[string equal -nocase TV-HD-DE $oldcat] && [string match -nocase *-ENCOUNTERS $::oldrls]} {set oldcat X264-DE}
                       if {[string equal -nocase TV-HD-DE $oldcat] && [string match -nocase *-DECENT $::oldrls]} {set oldcat X264-DE}  
			                  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
                         set nix [mysqlexec $mysql_(handle) "INSERT INTO `02b67c3eae678dc49209d6de4709a171` (`time`,`section`,`release`,`genre`,`files`,`size`,`group`,`prefrom`) VALUES ('$oldtime', '$oldcat', '$::oldrls', '$oldgenre', '$oldfiles', '$oldsize', '$oldgroup', '$::addoldnickname/Network-Addold')"]	                
			                 if { $::enabledebug  == 1 } { putlog "-ADDOLD- $addoldcat / $addoldtime / $addoldrls successfully added" }
			                 mysqlclose $mysql_(handle)
 
		}
	}
}
 
       if {$whatold == "!getold"} {
          set getoldrls [mysqlescape [lindex [split $arguments] 1]]
            set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
            set getoldsql [mysqlsel $mysql_(handle) "SELECT `time`, `section`, `release`, `files`, `size`, `genre`  FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$getoldrls'" -flatlist]
            mysqlclose $mysql_(handle)
              if { $getoldsql != "" } {
                set getoldtime [mysqlescape [lindex [split $getoldsql] 0]]
                set getoldcat [mysqlescape [lindex [split $getoldsql] 1]]
                set getoldrlssql [mysqlescape [lindex [split $getoldsql] 2]]
                set getoldfiles [mysqlescape [lindex [split $getoldsql] 3]]
                set getoldsize [mysqlescape [lindex [split $getoldsql] 4]]
                set getoldgenre [mysqlescape [lindex [split $getoldsql] 5]]
                          if { $getoldfiles == "0" } {set getoldfiles "-"}
                          if { $getoldsize == "0" } {set getoldsize "-"}
                          if { $getoldgenre == "" } {set getoldgenre "-"}
                          if { $getoldgenre == "{}" } {set getoldgenre "-"}
              if { $::enabledoldchan  == 1 } { putquick "PRIVMSG $::addoldchan :\!addold $getoldrlssql $getoldcat $getoldtime $getoldfiles $getoldsize $getoldgenre -" }
             }
           }
 
}
 
      }
 
putlog "wmPRE $relay(version) by $relay(author) Loaded!"
if { $::enabledebug == 1} { putlog "wmPRE $relay(version) DEBUG is -ON-" }
if { $::enabledebug == 0} { putlog "wmPRE $relay(version) DEBUG is -OFF-" }
if { $::enableprerelay == 1} { putlog "wmPRE $relay(version) PRE RELAY is -ON-" }
if { $::enableprerelay == 0} { putlog "wmPRE $relay(version) PRE RELAY is -OFF-" }
if { $::enableifrelay == 1} { putlog "wmPRE $relay(version) INFO RELAY is -ON-" }
if { $::enableifrelay == 0} { putlog "wmPRE $relay(version) INFO RELAY is -OFF-" }
if { $::enablesifrelay == 1} { putlog "wmPRE $relay(version) SITEINFO RELAY is -ON-" }
if { $::enablesifrelay == 0} { putlog "wmPRE $relay(version) SITEINFO RELAY is -OFF-" }
if { $::enablegnrelay == 1} { putlog "wmPRE $relay(version) GENRE RELAY is -ON-" }
if { $::enablegnrelay == 0} { putlog "wmPRE $relay(version) GENRE RELAY is -OFF-" }
if { $::enablenukerelay == 1} { putlog "wmPRE $relay(version) NUKE RELAY is -ON-" }
if { $::enablenukerelay == 0} { putlog "wmPRE $relay(version) NUKE RELAY is -OFF-" }
if { $::enabledelrelay == 1} { putlog "wmPRE $relay(version) DELPRE RELAY is -ON-" }
if { $::enabledelrelay == 0} { putlog "wmPRE $relay(version) DELPRE RELAY is -OFF-" }
if { $::enablenukechan == 1} { putlog "wmPRE $relay(version) Nuke2Chan is -ON-" }
if { $::enablenukechan == 0} { putlog "wmPRE $relay(version) Nuke2Chan is -OFF-" }
if { $::enabledelchan == 1} { putlog "wmPRE $relay(version) Del2Chan is -ON-" }
if { $::enabledelchan == 0} { putlog "wmPRE $relay(version) Del2Chan is -OFF-" }
