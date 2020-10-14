FROM centos:7.6.1810
MAINTAINER bingo wxdlong@qq.com


ARG MASTER=true
ENV PGDATA=/var/lib/pgsql/9.6/data \
    PG_HOME=/usr/pgsql-9.6/ \
    PG_PASS=/var/lib/pgsql/.pgpass \
    PASSWORD=replic

ENV PATH ${PG_HOME}/bin:$PATH

#install packages
RUN yum install -y yum-plugin-ovl tar vim iproute \
    https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
RUN yum install -y postgresql12-server


RUN echo "postgres" > ${PG_PASS}; \
    echo "*:5432:replication:replic:${PASSWORD}" >> ${PG_PASS} ; \
    chown postgres:postgres ${PG_PASS}; \
    chmod 0600 ${PG_PASS}; \
    echo "export PG_HOME=${PG_HOME}" > /var/lib/pgsql/.pgsql_profile ; \
    echo "export PATH=${PG_HOME}/bin:${PATH}" >> /var/lib/pgsql/.pgsql_profile ; \
    echo 'export PS1="\[\e[32;1m\][\[\e[33;1m\]\u\[\e[31;1m\]@\[\e[33;1m\]\h \[\e[36;1m\]\w\[\e[32;1m\]]\[\e[34;1m\]\$ \[\e[0m\]"' >> /var/lib/pgsql/.pgsql_profile ; \
    chown postgres:postgres /var/lib/pgsql/.pgsql_profile ;
  
 
COPY docker-entrypoint.sh /usr/local/bin/
COPY resource/* /home/initdb/

ENTRYPOINT ["docker-entrypoint.sh"]

# CMD ["/usr/sbin/sshd", "-D"]