ARG DOCKER_FROM
FROM ${DOCKER_FROM}
#ARG YUM_PROXY
#ENV YUM_PROXY="${YUM_PROXY}"
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/
ENV LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib
RUN yum -y install \
	yum-plugin-ovl rpm gcc automake make perl-macros.x86_64 rpm-build \
	readline-devel openssl-devel openssl pam-devel \
	perl-ExtUtils-MakeMaker.noarch mariadb-devel mariadb mariadb-server \
	glib2-devel gtk2-devel libtool git vim gdb hostname netloc \
	perl-Switch expect lua-devel rrdtool-devel lz4-devel json-c-devel \
	man2html libcurl-devel freeipmi-devel hdf5-devel numactl-devel \
	rdma-core-devel gcc-c++ flex libgcrypt-devel \
	strace ltrace gdb valgrind wget cmake sudo jansson-devel \
	openssh-server openssh-client pam-devel xterm gfortran \
	lua-devel xauth man mailx postfix python3 http-parser-devel \
	libyaml-devel mlocate gettext-devel texinfo java-11-openjdk
RUN git clone --depth 1 --single-branch -b v1.12.0 https://github.com/benmcollins/libjwt.git /root/libjwt/
WORKDIR /root/libjwt
RUN autoreconf --force --install && ./configure --prefix=/usr/local --sysconfdir=/etc/ && make -j && make install
RUN git clone --depth 1 --single-branch -b munge-0.5.13 https://github.com/dun/munge.git /root/munge/
WORKDIR /root/munge/
RUN autoreconf -i && ./configure --localstatedir=/var --prefix=/usr/local --sysconfdir=/etc/ >/dev/null && make -j >/dev/null && make install >/dev/null
RUN mkdir -p /etc/slurm /etc/pmix /var/log/mysql/
RUN git clone --depth 1 --single-branch -b release-2.0.22-stable https://github.com/libevent/libevent.git /root/libevent/
RUN git clone -b hdf5-1_10_6 --single-branch --depth 1 https://github.com/HDFGroup/hdf5.git /root/hdf5
WORKDIR /root/hdf5
RUN ./configure --prefix=/usr/local/ >/dev/null && make -j install >/dev/null
WORKDIR /root/libevent
RUN ./autogen.sh && ./configure --prefix=/usr/local >/dev/null && make -j >/dev/null && make install >/dev/null
RUN git clone --depth 1 --single-branch -b hwloc-2.0.2 https://github.com/open-mpi/hwloc.git /root/hwloc/
WORKDIR /root/hwloc
RUN ./autogen.sh && ./configure --prefix=/usr/local --sysconfdir=/etc/hwloc/ >/dev/null && make -j >/dev/null && make install >/dev/null
RUN git clone --depth 1 --single-branch -b v3.1.2 https://github.com/pmix/pmix.git /root/pmix/
WORKDIR /root/pmix
RUN ./autogen.pl && ./configure --prefix=/usr/local --sysconfdir=/etc/pmix/ --with-devel-headers --with-tests-examples  --enable-debug --with-libevent=/usr/local/ >/dev/null && make -j && make install >/dev/null
RUN git clone --depth 1 --single-branch -b master https://github.com/SchedMD/slurm.git /root/slurm
WORKDIR /root/slurm
RUN git config --global user.email "you@example.com"
RUN git config --global user.name "scale out"
RUN ./configure --enable-slurmrestd --enable-multiple-slurmd --enable-memory-leak-debug --enable-developer --disable-optimizations --with-munge=/usr/local/ --prefix=/usr/local \
	--enable-pam --sysconfdir=/etc/slurm --with-hdf5=/usr/local/bin/h5cc >/dev/null && \
	make -j >/dev/null && make install >/dev/null && make -j install-contrib >/dev/null
RUN cd contribs && make install
RUN /usr/sbin/groupadd -r slurm -g 1001 && \
	/usr/sbin/useradd -c "scheduler daemon" -d "/etc/slurm" -g slurm -s /bin/bash -u 1001 -r slurm && \
	/usr/sbin/groupadd -r slurmrestd -g 1002 && \
	/usr/sbin/useradd -c "REST daemon" -d "/etc/slurm" -g slurmrestd -s /bin/bash -u 1002 -r slurmrestd
RUN ln -s /usr/share/mysql/english/errmsg.sys /var/log/mysql/errmsg.sys
RUN mkdir -p /var/spool/slurm/statesave /var/spool/slurm/spool
RUN chown slurm:slurm -R /var/log/mysql/ /var/lib/mysql/ /var/spool/slurm
RUN /usr/sbin/groupadd -r munge
RUN /usr/sbin/useradd -c "MUNGE authentication service" -d "/usr/local/etc/munge" -g munge -s /bin/false -r munge
RUN mkdir -m 0700 -p /etc/munge/
RUN dd if=/dev/urandom bs=32 count=1 >/etc/slurm/jwt.key
RUN chown slurm:slurm /etc/slurm/jwt.key
RUN chmod 0600 /etc/slurm/jwt.key
RUN dd if=/dev/urandom bs=1 count=1024 >/etc/munge/munge.key
RUN touch /etc/munge/munge.seed
RUN chown munge:munge -R /etc/munge
RUN chmod 0400 /etc/munge/munge.key /etc/munge/munge.seed
RUN chown root:root /etc/munge/ -R
RUN git clone --depth 1 --single-branch -b pdsh-2.33 https://github.com/chaos/pdsh.git /root/pdsh/
WORKDIR /root/pdsh
RUN autoreconf -i && ./configure --without-rsh --with-ssh --prefix=/usr/local --sysconfdir=/etc/ --with-readline && make -j >/dev/null && make install >/dev/null
WORKDIR /root/
RUN wget -q 'https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.1.tar.gz' -O /root/openmpi.tar.gz
RUN tar -xzf /root/openmpi.tar.gz
WORKDIR /root/openmpi-4.0.1/
RUN ./configure --prefix=/usr/local --with-pmix=/usr/local --with-pmix-libdir=/usr/local/lib --with-pmi=/usr/local --with-slurm --with-devel-headers --enable-debug --without-cma \
	--with-libevent=/usr/local --with-libevent-header=/usr/local/include --with-libevent-libs=/usr/local/lib --with-hwloc=/usr/local/
RUN	make -j >/dev/null && make install >/dev/null
WORKDIR /root
RUN git clone --depth 1 --branch msmtp-1.8.6 https://github.com/marlam/msmtp-mirror.git msmtp
WORKDIR /root/msmtp
RUN autoreconf -i && ./configure && make -j >/dev/null && make install >/dev/null && \
	ln -nfs /usr/local/bin/msmtp /usr/sbin/sendmail && \
	ln -nfs /usr/local/bin/msmtp /usr/lib/sendmail
COPY msmtprc /usr/local/etc/msmtprc
ARG SUBNET
ENV SUBNET=${SUBNET}
RUN postconf -e "mydestination = cluster scaleout localhost.localdomain localhost" && \
	postconf -e "mynetworks = 127.0.0.0/8, ${SUBNET}.0.0/16" && \
	postconf -e "inet_interfaces = all" && \
	postconf -e "recipient_delimiter = +"
RUN newaliases
RUN postconf -e "mydestination = login login.localdomain cluster scaleout localhost.localdomain, localhost"

#Install OpenAPI generator jar directly (installing from source is very slow)
RUN mkdir -p /usr/local/jar/
RUN curl -s https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/4.3.1/openapi-generator-cli-4.3.1.jar -o /usr/local/jar/openapi-generator-cli.jar
RUN echo -e "#!/bin/bash\nexec java -jar /usr/local/jar/openapi-generator-cli.jar \$@" > /usr/local/bin/openapi-generator-cli && chmod 0755 /usr/local/bin/openapi-generator-cli
#https://pypi.org/project/openapi-python-client/

ENV SLURM_LOCAL_GLOBALS_FILE=/root/slurm/testunit/expect/globals.scaleout-slurmctld

#make ssh host keys
RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
	ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa && \
	ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519 && \
	echo 'password' | passwd root --stdin && \
	mkdir -p /root/.ssh && \
	ssh-keygen -f /root/.ssh/id_ecdsa -N '' -t ecdsa && \
	ssh-keygen -y -f /root/.ssh/id_ecdsa > /root/.ssh/id_ecdsa.pub && \
	cat /root/.ssh/id_ecdsa.pub >> /root/.ssh/authorized_keys && \
	chmod -R 0700 /root/.ssh

RUN groupadd bedrock && \
	groupadd managers
RUN for i in arnold bambam barney betty chip dino edna fred gazoo pebbles wilma; do \
	/usr/sbin/useradd -c $i -m -g users -G bedrock $i && \
	echo 'password' | passwd $i --stdin && \
	mkdir -p /home/$i/.ssh && \
	ssh-keygen -f /home/$i/.ssh/id_ecdsa -N '' -t ecdsa && \
	ssh-keygen -y -f /home/$i/.ssh/id_ecdsa > /home/$i/.ssh/id_ecdsa.pub && \
	cat /home/$i/.ssh/id_ecdsa.pub >> /home/$i/.ssh/authorized_keys && \
	chown -R $i:users /home/$i/.ssh && chmod -R 0700 /home/$i/.ssh; \
	done
RUN usermod -G managers fred && \
	usermod -G managers barney

#disable ssh host auth checks
RUN echo -e '\nNoHostAuthenticationForLocalhost=yes\nStrictHostKeyChecking=no' >> /etc/ssh/ssh_config
#ipv6 doesn't work in docker
RUN echo -e '\nAddressFamily inet\nUseDNS no' >> /etc/ssh/sshd_config

#override the ssh host keys to be known
RUN awk '{print "*", $1, $2}' </etc/ssh/ssh_host_ecdsa_key.pub >> /etc/ssh/ssh_known_hosts

#add pam module as first module
RUN echo -e '#%PAM-1.0\naccount    sufficient   pam_slurm_adopt.so\n' | cat - /etc/pam.d/sshd > /etc/pam.d/sshd2 && \
	mv /etc/pam.d/sshd2 /etc/pam.d/sshd

RUN echo -e 'SlurmdSpoolDir=/var/spool/slurm/spool' > /etc/nss_slurm.conf

#active slurm nss
RUN awk '{if (match($1, /^(passwd|group)/)) {print $1, "slurm", $2, $3} else {print $0}}' > /etc/nsswitch2.conf </etc/nsswitch.conf && \
	mv /etc/nsswitch2.conf /etc/nsswitch.conf

RUN mkdir -p /etc/PDSH && \
	echo -e "node00\nnode01\nnode02\nnode03\nnode04\nnode05\nnode06\nnode07\nnode08\nnode09" > /etc/PDSH/hosts && \
	echo -e "\nexport WCOLL=/etc/PDSH/hosts\n" >> /etc/bashrc && \
	echo -e "\nalias cls='clear'\n" >> /etc/bashrc && \
	echo -e "\nalias ..='cd ..'\n" >> /etc/bashrc && \
	echo -e "\nalias l='ls -alF'\n" >> /etc/bashrc

COPY slurm/* /etc/slurm/
RUN chmod 0600 /etc/slurm/slurmdbd.conf
RUN chown slurm:slurm /etc/slurm/slurmdbd.conf
COPY my.cnf /etc/
RUN sed -e "s#{SUBNET}#${SUBNET}#g" -i /etc/my.cnf
RUN ln -s /etc/my.cnf /usr/local/etc/my.cnf
COPY mysql.init /etc/
RUN chmod 0755 /etc/mysql.init
COPY mysql /usr/local/bin/mysql
COPY slurmctld.startup.sh /usr/local/bin/slurmctld.startup.sh
COPY slurmd.startup.sh /usr/local/bin/slurmd.startup.sh
COPY slurmdbd.startup.sh /usr/local/bin/slurmdbd.startup.sh
COPY login.startup.sh /usr/local/bin/login.startup.sh
COPY slurmrestd.startup.sh /usr/local/bin/slurmrestd.startup.sh
COPY globals.scaleout-slurmctld /root/slurm/testunit/expect/

RUN chmod 0755 /usr/local/bin/mysql
RUN chmod 0755 /usr/local/bin/slurmctld.startup.sh
RUN chmod 0755 /usr/local/bin/slurmdbd.startup.sh
RUN chmod 0755 /usr/local/bin/slurmd.startup.sh
RUN chmod 0755 /usr/local/bin/login.startup.sh
RUN chmod 0755 /usr/local/bin/slurmrestd.startup.sh
RUN mkdir -p /auth && chown -R slurm:slurm /auth && \
	chmod 0755 /auth

#RUN echo "define(`SMART_HOST', `login')dnl" >> /etc/mail/sendmail.mc
RUN echo -e "/usr/local/lib\n/usr/local/lib64" >> /etc/ld.so.conf.d/usr_local_lib.conf
RUN ldconfig
RUN mandb
RUN updatedb
WORKDIR /root/
