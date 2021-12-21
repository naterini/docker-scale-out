#Based on https://github.com/ubccr/xdmod/blob/xdmod10.0/.circleci/config.yml
FROM tools-ext-01.ccr.xdmod.org/xdmod-9.5.0:centos7.9-1.0
RUN yum update -y
RUN yum upgrade -y
RUN systemctl enable postfix.service mariadb.service httpd.service
RUN sed -e 's#:443#:80#' -e 's#SSLEngine on#SSLEngine off#g' -i /etc/httpd/conf.d/xdmod.conf
COPY resources.json /etc/xdmod/resources.json
COPY resource_specs.json /etc/xdmod/resource_specs.json

STOPSIGNAL SIGRTMIN+3
VOLUME ["/tmp", "/run", "/run/lock"]
COPY startup.sh /sbin/
CMD [ "/sbin/startup.sh" ]
EXPOSE 8082/tcp
