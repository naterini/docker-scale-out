HOST ?= mgmtnode

default: run

./docker-compose.yml: buildout.sh
	bash buildout.sh > ./docker-compose.yml

build: ./docker-compose.yml
	env COMPOSE_HTTP_TIMEOUT=360 docker-compose up --build --remove-orphans -d

stop:
	docker-compose down

nocache:
	unlink docker-compose.yml
	docker-compose build --no-cache

clean:
	docker-compose down --remove-orphans -t1 -v

uninstall:
	docker-compose down --rmi all --remove-orphans -t1 -v
	docker-compose rm -v

run: build
	docker-compose up --remove-orphans -d

bash: run
	docker-compose exec $(HOST) /bin/bash
