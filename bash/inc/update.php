<?php
 
mysql_connect('mysql.local', 'USER', 'PASS');
mysql_select_db('predb');
 
mysql_unbuffered_query("UPDATE `02b67c3eae678dc49209d6de4709a171` SET `siteinfo`='1', `size`='".$argv[2]."', `files`='".$argv[3]."' WHERE `release`='".$argv[1]."'");
 
mysql_close();
