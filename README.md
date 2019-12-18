# 用法
全自动配置主从replication模式postgres  

docker-compose up -d
```bash
wxd@long:~/Code/github$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                     NAMES
7f75e44e0be2        pgcluster:9.6.9     "docker-entrypoint.sh"   18 minutes ago      Up 18 minutes       0.0.0.0:32771->5432/tcp   pgslave
14abdfa31875        pgcluster:9.6.9     "docker-entrypoint.sh"   18 minutes ago      Up 18 minutes       0.0.0.0:32770->5432/tcp   pgmaster
```

# 配置主从postgres
## 配置`pg_hba.conf`
> samenet 在同一网段允许访问     

host    replication     replic        samenet            md5

## 配置`postgres.conf`

```conf
wal_level = replica			# minimal, replica, or logical
archive_mode = on		# enables archiving; off, on, or always
				# (change requires restart)
archive_command = 'cp %p /var/lib/pgsql/9.6/backups/%f'		# command to use to archive a logfile segment
				# placeholders: %p = path of file to archive
				#               %f = file name only
				# e.g. 'test ! -f /mnt/server/archivedir/%f && cp %p /mnt/server/archivedir/%f'
max_wal_senders = 2 		# max number of walsender processes
				# (change requires restart)
wal_keep_segments = 32		# in logfile segments, 16MB each; 0 disables
wal_sender_timeout = 60s	# in milliseconds; 0 disables
hot_standby = on			# "on" allows queries during recovery
```

## 配置`recovery.conf`
```conf
standby_mode = 'on'
primary_conninfo = 'user=replic password=replic host=pgslave port=5432 sslmode=prefer sslcompression=1 krbsrvname=postgres'
recovery_target_timeline = 'latest'
trigger_file = '/var/lib/pgsql/master'
restore_command = 'cp /var/lib/pgsql/9.6/backups/%f %p'
archive_cleanup_command = '/usr/pgsql-9.6/bin/pg_archivecleanup -d /var/lib/pgsql/9.6/backups/ %r >> /var/lib/pgsql/cleanup.log'
```

# 验证
## 查看主从sender进程
1. 主, `wal sender`
   ```bash
    [postgres@pgmaster ~/9.6/data]$ ps -ef | grep post
    postgres 127044     55  0 14:35 ?        00:00:00 postgres: wal sender process replic 172.26.0.3(46174) authentication
    postgres 127046     55  0 14:35 ?        00:00:00 postgres: wal sender process replic 172.26.0.3(46178) authentication
   ```

2. 从
   ```bash
    [postgres@pgslave ~]$ ps -ef | grep post
    postgres     57     45  0 15:07 ?        00:00:00 postgres: wal receiver process   streaming 0/3000060
   ```

## 查看数据库
1. 主,
   ```bash
   postgres=# \x
   Expanded display is on.
   postgres=# select * from pg_stat_replication;
   -[ RECORD 1 ]----+------------------------------
   pid              | 110
   usesysid         | 16384
   usename          | replic
   application_name | walreceiver
   client_addr      | 172.26.0.3
   client_hostname  |
   client_port      | 54464
   backend_start    | 2018-11-05 01:50:18.789676+00
   backend_xmin     |
   state            | streaming
   sent_location    | 0/3000220
   write_location   | 0/3000220
   flush_location   | 0/3000220
   replay_location  | 0/3000220
   sync_priority    | 0
   sync_state       | async
   ```
## `pg_controldata`
1. 主库 `in production`   
    ```bash
    [postgres@pgmaster ~]$ pg_controldata
    pg_control version number:            960
    Catalog version number:               201608131
    Database system identifier:           6620022152420352029
    Database cluster state:               in production
    pg_control last modified:             Mon 05 Nov 2018 07:11:52 AM UTC
    ```

2. 从库 `in archive recovery`   
   ```bash
    [postgres@pgslave ~]$ pg_controldata
    pg_control version number:            960
    Catalog version number:               201608131
    Database system identifier:           6620022152420352029
    Database cluster state:               in archive recovery
    pg_control last modified:             Mon 05 Nov 2018 07:11:52 AM UTC
   ```

## 测试

1. create table in master
   
    ```bash
    [postgres@pgmaster ~]$ psql
    psql (9.6.10)
    Type "help" for help.

    postgres=# create table test(
    postgres(#     id int,
    postgres(#     name char(50)
    postgres(# );
    CREATE TABLE
    postgres=# \d
            List of relations
    Schema | Name | Type  |  Owner
    --------+------+-------+----------
    public | test | table | postgres
    (1 row)
    ```
2. check table replic to slave
    ```bash
    [postgres@pgslave ~]$ psql
    psql (9.6.10)
    Type "help" for help.

    postgres=# \d
            List of relations
    Schema | Name | Type  |  Owner
    --------+------+-------+----------
    public | test | table | postgres
    (1 row)
    ```
3. create one data in master
    ```bash
    postgres=# insert into test (id,name) values (1,'bingo');
    INSERT 0 1
    postgres=# select * from test;
    id |                        name
    ----+----------------------------------------------------
    1 | bingo
    (1 row)

    postgres=#
    ```
4. check data in slave.  
    ```bash
    postgres=# select * from test;
    id |                        name
    ----+----------------------------------------------------
    1 | bingo
    (1 row)
    ```

5. 如果在slave上做写操作将会失败。
    ```bash
    postgres=#  insert into test (id,name) values (1,'bingo');
    ERROR:  cannot execute INSERT in a read-only transaction
    ```