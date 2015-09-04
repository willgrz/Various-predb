<?php

mysql_connect('mysql.local', 'USER', 'PASS');
mysql_select_db('predb');

if(mysql_num_rows(mysql_query("SELECT `releaseid` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release`='".$argv[1]."' AND `siteinfo` = '0'")) === 1) {

echo 1;
} else {

echo 0;
}

mysql_close();
