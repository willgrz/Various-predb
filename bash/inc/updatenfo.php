<?php

mysql_connect('mysql.local', 'predb', 'PASSWORD');
mysql_select_db('predb');

mysql_unbuffered_query("UPDATE `02b67c3eae678dc49209d6de4709a171` SET `nfofile`='".$argv[2]."', `nfofrom`='ARCHiVE/SITE' WHERE `release`='".$argv[1]."'");

mysql_close();
