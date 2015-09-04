package require mysqltcl
 
set ::sitechan "#A"
set ::spamchan "#A-spam"
set ::nukechan "#nuke"
set ::sitebot "BOT"
 
set ::timemysqlhost 127.0.0.1
set ::timemysqluser LOGIN
set ::timemysqlpass PASSWORD
set ::timemysqldb DATABASE
 
bind pubm   -|- *                pre:time
 
 
proc pre:time { nickname hostname handle channel arguments } {
 
	if {[string equal -nocase $channel $::sitechan] || [string equal -nocase $channel $::spamchan]} {
        if {[string match $::sitebot $nickname]} {
         set arguments [stripcodes c $arguments]
         #this is for a bot where NEW dir starts with "NEW in SECTION" so NEW* matches
           if {[string match NEW* $arguments]} {
           #split other if needed
            set release [lindex [split $arguments] 4]
             set section [lindex [split $arguments] 2]
               set racer [lindex [split $arguments] 6]
            if {[string match -nocase */* $release]} {return}
		set mysql_(handle) [mysqlconnect -host $::timemysqlhost -user $::timemysqluser -password $::timemysqlpass -db $::timemysqldb]
		set addpretime [mysqlsel $mysql_(handle) "SELECT `time` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release` = '$release'" -flatlist]  
      		mysqlclose $mysql_(handle)
              set localtime [unixtime]
              set pretime [expr $addpretime - $localtime]
              set pretime [string replace $pretime 0 0]
              set ago [duration $pretime]
              #fixing an annoying bug showing 41 years ago (unixtime 0) if the release has just been added in this second to the DB
               if {[string match -nocase *41*years* $ago]} { 
                 putquick "PRIVMSG $channel :\ Pretime 1s! "
                  return
                   }
             #ago is in hours/minutes/seconds etc. already formated, just output it
            putquick "PRIVMSG $channel :\ Pretime $ago"
 
              #3600 is 1hour, set to lower if needed
              if {$pretime >= 3600} { 
               #sections where backfillover limit is allowed
                if {$section == "MP3"} {return}
                   #archive needs backfill, naturally
                     if {[string match -nocase *ARCHIVE* $section]} {return}
                      #siteops are allowed to backfill, of course
                        if {[string match -nocase *siteop* $racer]} {return}
                         #if none of these matches, and it is really backfill - send nuke to nuke channel.
                            putquick "PRIVMSG $::nukechan :\!nuke $release 5 backfill" }
         }
        }
       }
      }
putlog "wm's Pretime script 1.1 loaded"
