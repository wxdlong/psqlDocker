#!/bin/bash

PGLOG=/var/log/pg.log
echo "start init postgres" | tee -a ${PGLOG}

echo "PGDATA: ${PGDATA}"
echo "MASTER: ${MASTER}"

if [ ${pg_type} == "master" ]; then
	{
		su - postgres -c "/usr/pgsql-12/bin/initdb -E UTF-8 --locale=en_US.UTF-8  -D ${PGDATA} -U postgres --pwfile=${PG_PASS}" | tee -a ${PGLOG}
		echo "initdb postgres " | tee -a ${PGLOG}
		echo "host    replication     ${PASSWORD}        samenet            md5" >>${PGDATA}/pg_hba.conf
		echo "host    all             all             samenet            md5" >>${PGDATA}/pg_hba.conf
		cp -rf /home/initdb/postgresql.conf ${PGDATA}
		su - postgres -c "/usr/pgsql-12/bin/pg_ctl -D ${PGDATA} start >/dev/null "
		echo "pg_ctl start" | tee -a ${PGLOG}
		while [ $(ss -atnp | grep :5432 | grep -q postgres || echo true) ]; do
			echo "waiting postgres start " | tee -a ${PGLOG}
			sleep 1
		done
		su - postgres -c "psql -c \"create role replic with login replication encrypted password '${PASSWORD}' \"" | tee -a ${PGLOG}
		echo "create role replic with login replication encrypted password '${PASSWORD}'" | tee -a ${PGLOG}

		echo "standby_mode = 'on'" >${PGDATA}/recovery.done
		echo "primary_conninfo = 'user=replic password=${PASSWORD} host=pgslave port=5432 sslmode=prefer sslcompression=1 krbsrvname=postgres'" >>${PGDATA}/recovery.done
		echo "recovery_target_timeline = 'latest'" >>${PGDATA}/recovery.done
		echo "trigger_file = '/var/lib/pgsql/master' " >>${PGDATA}/recovery.done
		echo "restore_command = 'cp /var/lib/pgsql/9.6/backups/%f %p' " >>${PGDATA}/recovery.done
		chmod 0644 ${PGDATA}/recovery.done
		chown postgres:postgres ${PGDATA}/recovery.done

		

		init_shell=/home/initdb/init.sh
        if [ -f ${init_shell} ]; then
		{
		   echo "init databse shell"
		   sh ${init_shell}
		}
		fi

		init_sql=/home/initdb/init.sql
		if [ -f ${init_sql} ]; then
		{
		   echo "init database sql"
		   chown postgres:postgres ${init_sql}
           su - postgres -c "psql -f ${init_sql}"
		}
		fi
	}

else {
	while [ true ]; do
		echo "waiting postgres start " | tee -a ${PGLOG}
		if >/dev/tcp/pgmaster/5432; then
			break
		fi
		sleep 2
	done
	su - postgres -c " /usr/pgsql-12/bin/pg_basebackup -h pgmaster -U replic -D ${PGDATA} -X stream -P -R" >> ${PGLOG}
    su - postgres -c "touch  ${PGDATA}/standby.signal"

	su - postgres -c "/usr/pgsql-12/bin/pg_ctl -D ${PGDATA} start"
	echo "pg_ctl start" | tee -a ${PGLOG}
}

fi

tail -f /dev/null
