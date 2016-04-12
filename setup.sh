#!/bin/sh

MAGENTO_CONSOLE=bin/magento

fix_permissions () {
  chmod 777 -R /magento/app/etc /magento/var /magento/pub
}

quit () {
  fix_permissions
  stop_db

  exit $1
}

MYSQLD_PID="0"
start_db () {
  [ "$MYSQL_HOST" == "localhost" ] && {
    echo "Starting mysql for setting magento up..."
    mysqld_safe &>/dev/null &
    MYSQLD_PID=$!
    MYSQL_HOST=127.0.0.1
    sleep 5
  }
}

stop_db () {
  [ "$MYSQLD_PID" != "0" ] && {
    echo -ne "Stopping mysql..."
    while kill -0 $MYSQLD_PID &>/dev/null; do
      echo -ne "."
      mysqladmin --user=$MYSQL_USERNAME --password=${MYSQL_PASSWORD} shutdown;
      sleep 4;
    done;
    echo;
  }
}

check_db_connection () {
  echo "Checking DB connection..."
  mysql --user=$MYSQL_USERNAME --password=${MYSQL_PASSWORD} --host=$MYSQL_HOST --port=$MYSQL_PORT -e ";" &>/dev/null
}

exists_db_table () {
  echo "Checking for database table..."
  mysqlshow -u $MYSQL_USERNAME -p${MYSQL_PASSWORD} --host $MYSQL_HOST --port $MYSQL_PORT $MYSQL_DATABASE &>/dev/null
}

create_db_table () {
  mysql -u $MYSQL_USERNAME -p${MYSQL_PASSWORD} --host $MYSQL_HOST --port $MYSQL_PORT -e "CREATE DATABASE $MYSQL_DATABASE;" &>/dev/null
}

magento_install () {
  $MAGENTO_ROOT/$MAGENTO_CONSOLE setup:install \
    --no-interaction \
    --use-rewrites=1 \
    --backend-frontname=admin \
    --session-save=db \
    --db-host=${MYSQL_HOST} \
    --db-name=${MYSQL_DATABASE} \
    --db-user=${MYSQL_USERNAME} \
    --db-password=${MYSQL_PASSWORD} \
    --base-url=http://${DOMAIN}/ \
    --language=${MAGENTO_LANGUAGE} \
    --timezone=${MAGENTO_TIMEZONE} \
    --currency=${MAGENTO_CURRENCY} \
    --admin-firstname=${MAGENTO_ADMIN_FIRSTNAME} \
    --admin-lastname=${MAGENTO_ADMIN_LASTNAME} \
    --admin-email=${MAGENTO_ADMIN_EMAIL} \
    --admin-user=${MAGENTO_ADMIN_USERNAME} \
    --admin-password=${MAGENTO_ADMIN_PASSWORD}
}

magento_upgrade () {
  $MAGENTO_ROOT/$MAGENTO_CONSOLE setup:upgrade \
    --no-interaction
}

magento_deploy () {
  fix_permissions
  $MAGENTO_ROOT/$MAGENTO_CONSOLE setup:static-content:deploy ${MAGENTO_LANGUAGE}
  fix_permissions
}

# Logic goes here
start_db

check_db_connection || {
  echo "Cannot connect to database"
  quit 1
}

if exists_db_table; then
  magento_upgrade || {
    echo "Cannot upgrade database, please check configs"
    quit 4
  }
else
  create_db_table || {
    echo "Cannot create magento table, please check permissions"
    quit 2
  }
  magento_install || {
    echo "Cannot complete installation"
    quit 3
  }
fi

magento_deploy || {
  echo "Cannot generate static content"
  quit 4
}

quit 0
