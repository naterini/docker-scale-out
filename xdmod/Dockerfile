#Based on https://github.com/ubccr/xdmod/blob/xdmod9.5/Dockerfile
FROM tas-tools-ext-01.ccr.xdmod.org/xdmod-9.0.0:centos7.8-0.1
RUN yum update -y
RUN yum upgrade -y
RUN systemctl enable postfix.service mariadb.service httpd.service
RUN sed -e 's#:443#:8082#' -e 's#SSLEngine on#SSLEngine off#g' -i /etc/httpd/conf.d/xdmod.conf

STOPSIGNAL SIGRTMIN+3
VOLUME ["/tmp", "/run", "/run/lock"]
COPY startup.sh /sbin/
CMD [ "/sbin/startup.sh" ]
EXPOSE 8082/tcp
