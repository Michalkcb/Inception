# Inception — instrukcja uruchomienia i pełna procedura oceny (PL)

UWAGI OGÓLNE
- Pliki konfiguracyjne znajdują się w katalogu `srcs`.
- Makefile buduje obrazy i uruchamia stack: `make up`.
- Dane trwałe są mapowane na hosta w `/home/${USER}/data/*`.
- Nie commituj prywatnych kluczy (np. `srcs/requirements/nginx/ssl/nginx.key`).

------------------------------------------------------------
SZYBKA INSTRUKCJA URUCHOMIENIA
------------------------------------------------------------
1. Przygotuj plik `.env` w `srcs/` (jeśli to potrzebne). Przykład:

```bash
cat > srcs/.env <<'EOF'
DOMAIN_NAME=mbany.42.fr
MYSQL_ROOT_PASSWORD=42
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wp_user
MYSQL_PASSWORD=42
WP_ADMIN_USER=mbany_owner
WP_ADMIN_PASSWORD=42
WP_ADMIN_EMAIL=mbany@42.fr
WP_USER=mbany_user
WP_PASSWORD=42
WP_EMAIL=user42@42.fr
EOF
```

2. Uruchom stack:

```bash
make up
```

3. Sprawdź status:

```bash
docker compose -f srcs/docker-compose.yml ps
```

4. Sprawdź dostępność usług testowych:

```bash
curl -k -I https://mbany.42.fr/   # sprawdź https (self-signed możliwe)
curl -I http://localhost:8080/    # statyczna strona (bonus)
```

------------------------------------------------------------
PEŁNA PROCEDURA
------------------------------------------------------------

Poniższe kroki prowadzą od pełnego czyszczenia środowiska do sprawdzenia wszystkich obowiązkowych punktów i bonusów.

Krok 0 — wyczyść stare zasoby (konieczne przed testem):

```bash
# Uruchom w pustym katalogu / na hoście — usuwa wszystko, co może kolidować
docker stop $(docker ps -qa) 2>/dev/null || true
docker rm $(docker ps -qa) 2>/dev/null || true
docker rmi -f $(docker images -qa) 2>/dev/null || true
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network rm $(docker network ls -q) 2>/dev/null || true
```

Krok 1 — uruchomienie projektu:

```bash
make up
```

Krok 2 — podstawowe weryfikacje Dockera:

```bash
docker compose -f srcs/docker-compose.yml ps
docker network ls
docker volume ls
```

Sprawdź, że w `docker compose ps` są usługi: `mariadb`, `wordpress`, `nginx` (oraz opcjonalnie: `redis`, `adminer`, `static_site`).

Krok 3 — sprawdź wolumeny (ważne dla persystencji danych):

```bash
# W zależności od tego jak został uruchomiony compose, nazwy wolumenów mogą być "prefixed" (np. 'srcs_...').
# Najpierw spróbuj sprawdzić z prefiksem, a jeśli nie istnieje, fallback do bezprefiksowej nazwy.
docker volume inspect srcs_wordpress_volume
docker volume inspect srcs_mariadb_volume
```

Pole `Mountpoint` powinno wskazywać na katalog hosta podobny do `/home/<login>/data/wordpress` i `/home/<login>/data/mariadb`.

Krok 4 — Nginx i TLS (wymóg: dostęp tylko po 443):

1. Upewnij się, że `docker compose -f srcs/docker-compose.yml ps` pokazuje `nginx` z zmapowanym portem `443:443` (brak `80:80`).
2. Jeżeli certyfikaty nie istnieją, wygeneruj je lokalnie (self-signed) i zrestartuj nginx:

```bash
mkdir -p srcs/requirements/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout srcs/requirements/nginx/ssl/nginx.key \
  -out srcs/requirements/nginx/ssl/nginx.crt \
  -subj "/C=PL/ST=MA/L=Warsaw/O=42School/OU=IT/CN=mbany.42.fr"
docker compose -f srcs/docker-compose.yml up -d --force-recreate nginx
```

3. Sprawdź logi nginx:

```bash
docker compose -f srcs/docker-compose.yml logs --tail=200 nginx
```

Powinieneś widzieć: "configuration file ... test is successful" i "Start Nginx (foreground)".

Krok 5 — dostęp do strony (https only)

1. Jeśli testujesz lokalnie i domena nie rozwiązuje się publicznie, dodaj do `/etc/hosts` wpis:

```bash
echo "127.0.0.1 mbany.42.fr" | sudo tee -a /etc/hosts
```

2. Spróbuj połączenia:

```bash
curl -I http://mbany.42.fr || true   # powinien być niedostępny
curl -k -I https://mbany.42.fr/       # użyj -k dla self-signed
```

Krok 6 — WordPress (php-fpm, użytkownicy, edycje)

Wejdź do kontenera wordpress i użyj WP-CLI:

```bash
docker exec -it wordpress bash -lc "wp core is-installed --allow-root"
docker exec -it wordpress bash -lc "wp user list --allow-root --format=table"
docker exec -it wordpress bash -lc "wp theme list --allow-root --format=table"
```

Weryfikuj, że:
- WordPress jest zainstalowany (brak ekranu instalacji),
- istnieje konto administratora (login NIE zawiera 'admin' ani 'Admin'),
- jest drugi użytkownik (np. rola author) — możesz utworzyć lub sprawdzić go WP-CLI.

Krok 7 — edytowanie strony i komentarze (sprawdzalność zmian)

Utwórz/zmodyfikuj stronę i ustaw ją jako statyczną front page:

```bash
# utworzenie strony (zwraca ID)
PAGE_ID=$(docker exec -it wordpress bash -lc "wp post create --post_type=page --post_title='Strona Główna' --post_status=publish --post_content='Wersja testowa' --allow-root --porcelain")
docker exec -it wordpress bash -lc "wp post update $PAGE_ID --post_content='Zmieniona treść' --allow-root"
docker exec -it wordpress bash -lc "wp option update show_on_front 'page' --allow-root && wp option update page_on_front $PAGE_ID --allow-root"
```

Dodaj komentarz testowy:

```bash
docker exec -it wordpress bash -lc "wp comment create --comment_post_ID=$PAGE_ID --comment_author='Tester' --comment_author_email=tester@example.com --comment_content='Komentarz testowy' --comment_approved=1 --allow-root"
```

Sprawdź w przeglądarce, że treść i komentarz są widoczne.

Krok 8 — MariaDB (weryfikacja bazy)

```bash
docker exec -it mariadb bash -lc "mysql -uroot -p\"${MYSQL_ROOT_PASSWORD:-42}\" -e 'SHOW DATABASES;'"
docker exec -it mariadb bash -lc "mysql -u\"${MYSQL_USER:-wp_user}\" -p\"${MYSQL_PASSWORD:-42}\" -e 'SHOW DATABASES;'"
```

Sprawdź, że baza `wordpress_db` istnieje.

Krok 9 — wolumeny i persystencja (test restart)

1. Zrestartuj maszynę (reboot). Po restarcie uruchom `make up`.
2. Sprawdź, czy zmiany w WordPress (strony, komentarze) oraz pliki w `/home/<login>/data/wordpress` przetrwały.

Krok 10 — Redis (bonus)

```bash
docker exec -it redis redis-cli PING
# oczekiwane: PONG
```

Krok 11 — Adminer (bonus)

Adminer wystawiony jest na porcie 8081 (jeśli serwis uruchomiony):

```bash
curl -I http://localhost:8081/
```

Krok 12 — statyczna strona (bonus)

```bash
curl -I http://localhost:8080/
```

Krok 13 — podsumowanie warunków do zaliczenia

- `Makefile` w katalogu głównym — musi być i działać (`make up`).
- `srcs/` zawiera Dockerfile dla każdego serwisu.
- brak `network: host` i `links:` w `docker-compose.yml`.
- Nginx nasłuchuje tylko na 443 i używa TLS.
```bash
docker exec -it nginx bash -lc "ls -l /etc/nginx/ssl || ls -l /etc/ssl || true"
docker exec -it nginx bash -lc "sed -n '1,240p' /etc/nginx/sites-available/default || true"
```
- WordPress z php-fpm działa i jest zainstalowany.
```bash
docker compose -f srcs/docker-compose.yml ps
```
- MariaDB działa, a wolumeny są bind-mounted do `/home/<login>/data/`.
```bash
docker inspect --format '{{json .Mounts}}' mariadb | jq
docker exec -it mariadb bash -lc "mysql -uroot -p\"${MYSQL_ROOT_PASSWORD:-42}\" -e 'SHOW DATABASES;'"
docker volume inspect srcs_mariadb_volume --format '{{.Mountpoint}}'
```
- Można edytować stronę w panelu admin i zmiany są trwałe po restarcie — to potwierdza persystencję.

Krok 14 — przydatne debug-komendy

```bash
docker compose -f srcs/docker-compose.yml logs --tail=200 nginx
docker compose -f srcs/docker-compose.yml logs --tail=200 wordpress
docker compose -f srcs/docker-compose.yml logs --tail=200 mariadb
docker exec -it wordpress bash -lc "sed -n '1,240p' /var/www/html/wp-config.php"
```

Krok 15 — co zrobić, jeśli Nginx nie startuje z powodu certyfikatu

Sprawdź, czy klucz i cert są poprawne (PEM). Jeśli w repo jest placeholder, wygeneruj poprawny cert openssl (patrz Krok 4) i restartuj nginx.

------------------------------------------------------------
BONUS: 
------------------------------------------------------------

Przed przesłaniem repo do oceny upewnij się, że nie zawierasz w nim żadnych sekretów ani prywatnych kluczy. Poniżej
krótka checklistka i polecenia, które warto wykonać:
1) Usuń prywatne klucze i pliki z wrażliwymi danymi
	- Upewnij się, że w repo nie ma prywatnego klucza TLS. Przykładowo plik `srcs/requirements/nginx/ssl/nginx.key` powinien
	nie być commitowany. Projekt zawiera `.gitignore` z odpowiednim wpisem.
2) Użyj pliku `.env` lokalnie, nie dodawaj go do repo
	- W pliku `srcs/.env` trzymaj zmienne środowiskowe (hasła, domena). Nie commituj go. Możesz dodać `srcs/.env.sample` z
	przykładowymi, pustymi wartościami, które oceniający może wypełnić.
3) Jak wygenerować lokalny self-signed cert (jeśli oceniający chcą go lokalnie):
```bash
# na hoście (w katalogu repo)
mkdir -p srcs/requirements/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout srcs/requirements/nginx/ssl/nginx.key \
	-out srcs/requirements/nginx/ssl/nginx.crt \
	-subj "/C=PL/ST=MA/L=Warsaw/O=42School/OU=IT/CN=mbany.42.fr"
```
4) Co oceniacz powinien otrzymać (krótko)
	- Repo zawiera katalog `srcs` z Dockerfile dla każdego serwisu (mariadb, wordpress, nginx oraz dodatkowe serwisy bonusowe).
	- `Makefile` buduje obrazy i uruchamia stos (`make up`).
	- Instrukcje w README wyjaśniają jak uruchomić testy: sprawdzenie health, dostęp do strony, test Redis (PING), dostęp do
	Adminer i statycznej strony.
5) Szybkie polecenia sanity-check przed wysłaniem:
```bash
# upewnij się, że .env nie jest w repo (lokalny)
git status --porcelain | grep srcs/.env || true

# uruchom stack i sprawdź podstawowe rzeczy
make clean || true
make up
docker compose -f srcs/docker-compose.yml ps
docker exec -it redis redis-cli PING
curl -k -I https://mbany.42.fr/ || curl -I http://localhost:8080/
```



Szybkie kroki:
1. Skonfiguruj `srcs/.env` (przykładowe zmienne są tam już obecne).
2. Upewnij się, że katalogi hosta istnieją (Makefile tworzy `/home/${USER}/data/*`).
3. Uruchom:

```bash
make up
```

Sprawdzenie stanu:

```bash
docker compose -f srcs/docker-compose.yml ps
docker inspect -f '{{json .State.Health}}' mariadb | jq .
curl -k -I https://mbany.42.fr/
```

Dodatkowe serwisy (bonus)

Jak prezentować serwisy bonusowe — polecenia (ręcznie)
---------------------------------------------------
Poniżej znajdują się proste polecenia, które można wkonać, żeby pokazać działanie serwisów bonusowych podczas prezentacji.

1) Szybkie sprawdzenie uruchomionych kontenerów i mapowań portów

```bash
docker compose -f srcs/docker-compose.yml ps
```

Pokazuje listę uruchomionych usług i przekierowane porty (np. `8080->80`, `8081->80`, `443->443`, `21->21`, itp.).

2) Redis — pokazanie, że cache działa

W terminalu uruchom polecenie:

```bash
docker exec -it redis redis-cli PING
# oczekiwane: PONG
```

Redis działa jako szybkie, pamięciowe repozytorium klucz-wartość (in-memory), wykorzystywane tutaj jako object cache dla WordPress — przechowuje tymczasowe wyniki i sesje, żeby nie odpytywać za każdym razem bazy danych.
Dzięki temu strona szybciej odpowiada, a obciążenie MariaDB jest mniejsze, co upraszcza testowanie wydajności i poprawia responsywność podczas oceny.

3) Static site — otwórz / pokaż nagłówek strony statycznej

```bash
curl -I http://localhost:8080/
# spodziewane: HTTP/1.1 200 OK
curl -s http://localhost:8080/ | sed -n '1,20p'
```

Statyczna strona to prosty serwis, który służy wyłącznie do serwowania plików HTML/CSS bez PHP czy bazy danych — działa jako lekki serwer plików na porcie 8080.
Jest użyteczna, bo pozwala pokazać dodatkowy, niezależny serwis (np. landing page lub demo) bez wpływu na aplikację WordPress i bez dodatkowego obciążenia bazy.

4) Adminer (DB GUI) — sprawdzenie dostępności panelu

```bash
curl -I http://localhost:8081/
# lub otwórz w przeglądarce: http://localhost:8081/
```

Adminer to lekki interfejs webowy do zarządzania bazą danych (analogiczny do phpMyAdmin): łączy się z MariaDB i pozwala przeglądać, edytować oraz wykonywać zapytania SQL.
Jest przydatny podczas oceny, bo umożliwia szybkie, graficzne sprawdzenie zawartości bazy i debug bez konieczności używania CLI.

5) FTP — podstawowa demonstracja (po uruchomieniu usługi `ftp`)

Upewnij się, że w `srcs/.env` masz ustawione `FTP_USER` i `FTP_PASS` (lokalnie, nie commituj pliku).

Sprawdź, czy hostowy katalog istnieje i zawiera pliki do pokazania:

```bash
ls -la /home/${USER}/data/ftp
```

Połącz się z serwerem FTP z hosta (przykład z `lftp`):

```bash
# jeśli masz zainstalowane lftp
lftp -u "$FTP_USER","$FTP_PASS" -p 21 127.0.0.1

# lub prosty test z ftp (uwaga: hasło przesyłane otwartym tekstem)
ftp -p 127.0.0.1 21
```

Jeśli chcesz pokazać, że plik został zapisany na hostzie i jest widoczny w kontenerze FTP:

```bash
# po stronie hosta
ls -la /home/${USER}/data/ftp

# wewnątrz kontenera (opcjonalnie)
docker exec -it ftp ls -la /home/ftpusers
```

Serwer FTP udostępnia katalog użytkownika przez protokół FTP (tekstowy, nieszyfrowany) i pozwala na przesyłanie plików przy użyciu konta FTP skonfigurowanego w `srcs/.env`.
To przydatny przykład usługi przechowywania plików, bo pokazuje transfer i trwałość danych — pliki wrzucone przez FTP są widoczne w hostowym katalogu `/home/<login>/data/ftp`.

6) Uptime / Health (bonus) — jak pokazać

Uptime to prosty serwis zwracający JSON z aktualnym czasem i statusem usługi. Serwis jest zbudowany lokalnie i wystawiony na porcie 8082; podczas prezentacji wystarczy wykonać żądanie HTTP, aby pokazać, że działa.

Demo:

```bash
# zbuduj i uruchom serwis (jeśli jeszcze nie uruchomiony)
docker compose -f srcs/docker-compose.yml up -d --build uptime

# sprawdź nagłówki (oczekiwane: 200)
curl -I http://localhost:8082/

# pobierz status w formacie JSON (zawiera pole time)
curl -sS http://localhost:8082/status.json
```

Użyteczność: to prosty, niezależny endpoint monitoringu/healthcheck, idealny do pokazania dodania małego micro‑servisu oraz do testów routingu i mapowania portów bez angażowania WordPressa.

7) Sprawdź logi serwisów bonusowych (jeśli coś nie działa)

```bash
docker compose -f srcs/docker-compose.yml logs --tail=100 redis
docker compose -f srcs/docker-compose.yml logs --tail=100 static_site
docker compose -f srcs/docker-compose.yml logs --tail=100 adminer
docker compose -f srcs/docker-compose.yml logs --tail=200 ftp
docker compose -f srcs/docker-compose.yml logs --tail=100 uptime
```

7) Pokaz portów i mountów (dowód persystencji danych dla bonusów)

```bash
docker inspect -f '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' ftp
docker inspect -f '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' redis
```