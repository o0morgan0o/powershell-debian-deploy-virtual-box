#!/bin/bash
sed -i "s/{{DB_PASS}}/$(cat ~/TMP_USER_PASS)/g" /srv/postfixadmin/config.local.php
sed -i 's#{{SETUP_PASS}}#'"$(cat ~/TMP_SETUP_PASS)"'#g' /srv/postfixadmin/config.local.php