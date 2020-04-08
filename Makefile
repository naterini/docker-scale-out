HOST ?= mgmtnode
BUILD ?= up --build --remove-orphans -d
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
	docker-compose down --remove-orphans -t1 -v

uninstall:
	docker-compose down --rmi all --remove-orphans -t1 -v
	docker-compose rm -v

run: build
	docker-compose up --remove-orphans -d

bash: run
	docker-compose exec $(HOST) /bin/bash
