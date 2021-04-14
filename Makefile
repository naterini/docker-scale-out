HOST ?= mgmtnode
BUILD ?= up --build --remove-orphans -d

.EXPORT_ALL_VARIABLES:
SUBNET=10.11
SUBNET6=2001:db8:1:1::

default: run

./docker-compose.yml: buildout.sh
	bash buildout.sh > ./docker-compose.yml

build: ./docker-compose.yml
	env COMPOSE_HTTP_TIMEOUT=3000 docker-compose $(BUILD)

stop:
	docker-compose down

set_nocache:
	$(eval BUILD := build --no-cache)

nocache: set_nocache build

clean:
	docker-compose kill -s SIGKILL
	docker-compose down --remove-orphans -t1 -v

uninstall:
	docker-compose down --rmi all --remove-orphans -t1 -v
	docker-compose rm -v

run: build
	docker-compose up --remove-orphans -d

cloud:
	touch cloud_socket
	env CLOUD=1 bash buildout.sh > ./docker-compose.yml
	python3 cloud_monitor.py3 docker-compose up --build --remove-orphans --scale cloud=0 -d

bash:
	docker-compose exec $(HOST) /bin/bash
