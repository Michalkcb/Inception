# Plik Makefile musi być w katalogu głównym projektu (~/inception/)

# Używamy docker compose v2 (docker compose)
COMPOSE = docker compose -f srcs/docker-compose.yml

# Buduje, tworzy i uruchamia wszystkie kontenery
up:
	# KLUCZOWA POPRAWKA: Tworzenie katalogów dla bind mount w /home/${USER}/data
	mkdir -p /home/${USER}/data/mariadb /home/${USER}/data/wordpress /home/${USER}/data/redis
	# Opcja --build wymusza ponowną budowę obrazów
	# Opcja -d uruchamia w tle
	$(COMPOSE) up --build -d

# Zatrzymuje i usuwa kontenery, sieci (ale zachowuje wolumeny)
down:
	$(COMPOSE) down

# Czyści wszystko: kontenery, obrazy, sieci i WOLUMENY (usuwa wszystkie dane)
clean:
	$(COMPOSE) down -v --rmi all
	# Opcjonalnie: upewnij się, że katalogi na hoście są usunięte
	# Usuń katalogi danych utworzone przez cel `up` (bez ryzyka usunięcia innych katalogów)
	sudo rm -rf /home/${USER}/data/mariadb /home/${USER}/data/wordpress /home/${USER}/data/redis || true

# Domyślny cel
all: up

.PHONY: up down clean all
