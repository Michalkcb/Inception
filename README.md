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