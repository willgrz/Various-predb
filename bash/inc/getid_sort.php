<?php

mysql_connect('mysql.local', 'USER', 'PASS');
mysql_select_db('predb');

$qry = mysql_query("SELECT `releaseid`, `nfofrom` FROM `02b67c3eae678dc49209d6de4709a171` WHERE `release`='".$argv[1]."'");

if(mysql_num_rows($qry) === 1) {
	$r = mysql_fetch_assoc($qry);
	if($r['nfofrom'] === NULL) {
		echo '1';
	} else {
		echo '2';
	}
} else {
	echo '0';
}

mysql_free_result($qry);
mysql_close();
