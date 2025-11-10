# Inception — instrukcja uruchomienia i pełna procedura oceny (PL)

Ten plik zawiera: krótkie instrukcje uruchomienia, oraz szczegółową, krok-po-kroku procedurę, której powinien użyć egzaminator podczas oceny projektu.
Wszystkie polecenia wykonuj z katalogu głównego repozytorium (~/inception).

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
PEŁNA PROCEDURA DLA OCENIACZA
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

Krok 13 — podsumowanie warunków do zaliczenia (eval.txt)

- `Makefile` w katalogu głównym — musi być i działać (`make up`).
- `srcs/` zawiera Dockerfile dla każdego serwisu.
- brak `network: host` i `links:` w `docker-compose.yml`.
- Nginx nasłuchuje tylko na 443 i używa TLS.
- WordPress z php-fpm działa i jest zainstalowany.
- MariaDB działa, a wolumeny są bind-mounted do `/home/<login>/data/`.
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
BONUS: automatyzacja sprawdzeń
------------------------------------------------------------
Jeśli chcesz, mogę dodać skrypt `scripts/run_eval_checks.sh`, który uruchomi większość powyższych komend i wypisze PASS/FAIL.

---

Powodzenia przy ocenie — jeśli chcesz, od razu dodam `scripts/run_eval_checks.sh` lub skrócę instrukcję do jednej komendy do uruchomienia.
Przygotowanie przed commitem / instrukcje dla oceny
-----------------------------------------------
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
Jeśli chcesz, mogę:
- dodać `srcs/.env.sample` z pustymi wartościami,
- dodać skrypt `scripts/prepare_release.sh`, który automatycznie czyści pliki tymczasowe i tworzy plik `.tar.gz` gotowy do przesłania.
Projekt Inception — instrukcja uruchomienia i weryfikacji

Krótko:
- Wszystkie pliki konfiguracyjne znajdują się w katalogu `srcs`.
- Uruchamianie: `make up` (buduje obrazy i podnosi kontenery).
- Czyszczenie: `make clean` (usuwa kontenery, obrazy i wolumeny).

Wymagania środowiskowe:
- Docker i Docker Compose (v2) zainstalowane na maszynie.
- Uruchomić na Virtual Machine zgodnie z subject.

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

Bezpieczeństwo:
- Nie umieszczaj haseł w Dockerfile. Trzymaj je w `srcs/.env` lub w `secrets/` (nie commituj). 

Dodatkowe notatki:
- Wolumeny hosta są montowane w `/home/${USER}/data/mariadb` i `/home/${USER}/data/wordpress`.
- Obrazy mają nazwy odpowiadające serwisom: `mariadb`, `wordpress`, `nginx`.

Certyfikaty TLS
----------------
Domyślnie projekt uruchamia Nginx z certyfikatem self-signed umieszczonym w `srcs/requirements/nginx/ssl/nginx.crt` i
`srcs/requirements/nginx/ssl/nginx.key`. Taki cert spełnia wymóg działania tylko na HTTPS (port 443, TLSv1.2/1.3),
ale przeglądarki będą zgłaszać ostrzeżenie (self-signed). Poniżej masz proste opcje jak to zmienić na bardziej odpowiednie
dla testów lub produkcji.

Opcja 1 — zostawić self-signed (szybko, domyślne):

	- Pliki certyfikatu znajdują się w `srcs/requirements/nginx/ssl/`.
	- Upewnij się, że klucz prywatny nie trafi do repozytorium (dodaj do `.gitignore` wpis `srcs/requirements/nginx/ssl/*.key`).

Opcja 2 — użyć mkcert (lokalnie zaufany cert dla developmentu):

	1. Zainstaluj mkcert (instrukcje: https://github.com/FiloSottile/mkcert).
	2. Uruchom na hoście:

```bash
mkcert -install
mkcert mbany.42.fr
```

	3. Skopiuj wygenerowane pliki (`mbany.42.fr.pem` i `mbany.42.fr-key.pem`) do `srcs/requirements/nginx/ssl/` i zmień ich nazwy
		 na `nginx.crt` i `nginx.key` lub zaktualizuj entrypoint Nginx.
	4. Restartuj nginx: `docker compose -f srcs/docker-compose.yml up -d --build nginx`.

Opcja 3 — użyć Let's Encrypt (produkcyjnie, wymagane publiczne IP i port 80 albo DNS-01):

	- Jeśli domena `mbany.42.fr` wskazuje publicznie na Twoją VM i możesz chwilowo wystawić port 80, najprościej użyć `certbot` z
		trybem `--standalone` lub z weryfikacją HTTP. Przykład (na hoście):

```bash
sudo certbot certonly --standalone -d mbany.42.fr
# certyfikaty będą w /etc/letsencrypt/live/mbany.42.fr/
# potem zamontuj je do kontenera nginx i zrestartuj nginx
```

	- Alternatywnie użyj DNS-01 challenge (jeśli masz dostęp API do strefy DNS) — pozwala wystawić certyfikat bez otwierania portu 80.

Uwaga o bezpieczeństwie
-----------------------
- Nigdy nie commituj prywatnych kluczy do repo. Dodaj `srcs/requirements/nginx/ssl/*.key` do `.gitignore`.
- Dla oceny projektu: ważne jest, żeby Nginx był jedynym punktem wejścia na porcie 443 i żeby obsługiwał TLSv1.2/1.3 — to już
	jest spełnione. Jeśli chcesz, przygotuję automatyzację generowania certyfikatu Let's Encrypt lub skrypt do wygenerowania
	mkcert i podmiany plików w repo.

Dodatkowe serwisy (bonus)
-------------------------
W repo dodałem dwa przykładowe serwisy bonusowe, aby ułatwić ocenę i testy:

- `redis` — serwis cache (zbudowany z `srcs/requirements/redis/Dockerfile`). Dane Redis są przechowywane w wolumenie
	bind-mounted do `/home/${USER}/data/redis` na hoście.
- `static_site` — prosty serwis statyczny (nie-PHP) z `srcs/requirements/static_site` i `index.html`, wystawiony na porcie
	8080 hosta.

Jak testować lokalnie
---------------------
- Sprawdź listę działających kontenerów:

```bash
docker compose -f srcs/docker-compose.yml ps
```

- Test Redis (wewnątrz kontenera):

```bash
docker exec -it redis redis-cli PING
# spodziewany output: PONG
```

- Test statycznej strony:

```bash
curl -I http://localhost:8080/
# spodziewane: HTTP/1.1 200 OK
curl -s http://localhost:8080/ | sed -n '1,20p'
# zobaczysz prosty HTML index
```

Uwagi:
- Każdy dodatkowy serwis musi mieć własny `Dockerfile` i działać w dedykowanym kontenerze — to zostało spełnione dla powyższych
	przykładów.
- Jeżeli chcesz, mogę dodatkowo: zintegrować Redis z WordPressem (do cache; wymaga instalacji PHP Redis extension i
	konfiguracji WP), dodać Adminer lub FTP — napisz, który z nich chcesz mieć zaimplementowany dalej.


Jeśli chcesz, mogę teraz uruchomić `make clean` i `make up` i sprawdzić end-to-end — potwierdź, żebym kontynuował.