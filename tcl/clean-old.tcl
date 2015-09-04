proc !cleanall { arguments } {
 hashclean $arguments
 idclean
}
 
proc hashclean { arguments } {
  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
   putlog "[mysqlexec $mysql_(handle) "DELETE FROM `hashes` WHERE `time` <= [expr [unixtime] - [expr $arguments  * 60]]"] dead Hashes removed"
    mysqlclose $mysql_(handle) 
}
 
proc idclean {} {
  set mysql_(handle) [mysqlconnect -host $::amysqlhost -user $::amysqluser -password $::amysqlpass -db $::themysqldb]
   putlog "[mysqlexec $mysql_(handle) "DELETE FROM `b8e2e0e422cae4838fb788c891afb44f` WHERE `releaseid` = 0"] dead Nukes removed"
   putlog "[mysqlexec $mysql_(handle) "DELETE FROM `19503eb6973fcbf266ed3c3faada235e` WHERE `releaseid` = 0"] dead Delpres removed"
    mysqlclose $mysql_(handle) 
}
