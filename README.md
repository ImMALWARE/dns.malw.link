# dns.malw\.link

Здесь 5 веток:

1. [master](https://github.com/ImMALWARE/dns.malw.link/tree/master) — описание, файл hosts, mobileconfig
2. [dns-server](https://github.com/ImMALWARE/dns.malw.link/tree/dns-server) — DNS сервер
3. [sni-proxy](https://github.com/ImMALWARE/dns.malw.link/tree/sni-proxy) — SNI Proxy
4. [dns-and-sni-proxy](https://github.com/ImMALWARE/dns.malw.link/tree/dns-and-sni-proxy) — DNS сервер и SNI Proxy для установки на единственный сервер
5. [web](https://github.com/ImMALWARE/dns.malw.link/tree/web) — Веб-страницы ([info.dns.malw.link](https://info.dns.malw.link))

---

# Запуск DNS и SNI Proxy на одном сервере

1. Убедитесь, что у вас установлен Docker и Docker Compose. Если не знаете как — спросите у ChatGPT.
2. Клонируйте репозиторий:

   ```bash
   git clone --single-branch -b dns-and-sni-proxy https://github.com/ImMALWARE/dns.malw.link
   cd dns.malw.link
   ```

## Если вам нужны DNS over HTTPS и DNS over TLS

1. Убедитесь, что ваш домен привязан к IP сервера.
2. Создайте папку `certs` в корне проекта.
3. Поместите в неё SSL-сертификаты с именами `fullchain.cer` и `key.key`.

   > Можете использовать, например, [acme.sh](https://github.com/acmesh-official/acme.sh) для получения сертификатов.

4. В `nginx.conf` поменяйте домен `dns.malw.link` на ваш домен:

   ```conf
   map $ssl_preread_server_name $allowed_domain {
      dns.malw.link 2;
      include /etc/nginx/whitelist_domains.conf;
   ```

## Если вам не нужны DNS over HTTPS и DNS over TLS

1. В `docker-compose.yml` закомментируйте строки:

   ```yaml
   # - "853:853/tcp"
   # - ./certs:/etc/dnsdist/certs:ro
   ```

2. В `dnsdist.conf` закомментируйте строки:

   ```dnsdist
   -- addTLSLocal("0.0.0.0:853", "/etc/dnsdist/certs/fullchain.cer", "/etc/dnsdist/certs/key.key")
   -- addDOHLocal("0.0.0.0:8053", "/etc/dnsdist/certs/fullchain.cer", "/etc/dnsdist/certs/key.key", "/dns-query")
   ```

## Дальнейшие действия

В файле `dnsdist.conf` замените IP-адреса:

```dnsdist
addAction(QNameSuffixRule(proxy_with_subdomains), SpoofAction({"2a05:541:104:7f::1", "45.95.233.23", "185.246.223.127"}))
addAction(QNameSetRule(proxy), SpoofAction({"2a05:541:104:7f::1", "45.95.233.23", "185.246.223.127"}))
```

Замените на IP-адреса текущего сервера. Чтобы его узнать, выполните эти команды:

```bash
curl -4 ip.wtf  # IPv4 адрес
curl -6 ip.wtf  # IPv6 адрес
```

Формат:

```json
{"тут ipv6", "тут ipv4"}
```

Если IPv6 нет:

```json
{"тут ipv4"}
```

Для запуска/обновления списка доменов используйте:

```bash
./update_domains.sh
```

---

# Запуск только DNS на сервере

1. Убедитесь, что у вас установлен Docker и Docker Compose.
2. Клонируйте нужную ветку:

   ```bash
   git clone --single-branch -b dns-server https://github.com/ImMALWARE/dns.malw.link
   cd dns.malw.link
   ```

## Если вам нужны DNS over HTTPS и DNS over TLS

1. Убедитесь, что домен привязан к IP.
2. Создайте папку `certs` в корне проекта.
3. Поместите в неё SSL-сертификаты с именами `fullchain.cer` и `key.key`.

   > Можете использовать, например, [acme.sh](https://github.com/acmesh-official/acme.sh) для получения сертификатов.

4. В `nginx.conf` поменяйте домен `dns.malw.link` на ваш домен:

   ```conf
   map $ssl_preread_server_name $allowed_domain {
      dns.malw.link 2;
      include /etc/nginx/whitelist_domains.conf;
   ```

## Если вам не нужны DNS over HTTPS и DNS over TLS

1. В `docker-compose.yml` закомментируйте:

   ```yaml
   # - "853:853/tcp" # DNS over TLS
   # - "443:443/tcp" # DNS over HTTPS
   # - ./certs:/etc/dnsdist/certs:ro
   ```

2. В `dnsdist.conf` закомментируйте:

   ```dnsdist
   -- addTLSLocal("0.0.0.0:853", "/etc/dnsdist/certs/fullchain.cer", "/etc/dnsdist/certs/key.key")
   -- addDOHLocal("0.0.0.0:443", "/etc/dnsdist/certs/fullchain.cer", "/etc/dnsdist/certs/key.key", "/dns-query")
   ```

## Дальнейшие действия

В `dnsdist.conf` замените:

```dnsdist
addAction(QNameSuffixRule(proxy_with_subdomains), SpoofAction({"2a05:541:104:7f::1", "45.95.233.23", "185.246.223.127"}))
addAction(QNameSetRule(proxy), SpoofAction({"2a05:541:104:7f::1", "45.95.233.23", "185.246.223.127"}))
```

На IP-адреса вашего сервера SNI Proxy.

Узнать IP-адреса можно командами (выполните на сервере, где запущен SNI Proxy):

```bash
curl -4 ip.wtf  # IPv4
curl -6 ip.wtf  # IPv6
```

Формат:

```json
{"тут ipv6", "тут ipv4"}
```

Если IPv6 нет:

```json
{"тут ipv4"}
```

Для запуска/обновления списка доменов используйте:

```bash
./update_domains.sh
```

---

# Запуск только SNI Proxy на сервере

1. Убедитесь, что у вас установлен Docker и Docker Compose.

2. Клонируйте ветку:

   ```bash
   git clone --single-branch -b sni-proxy https://github.com/ImMALWARE/dns.malw.link
   cd dns.malw.link
   ```

3. Для запуска/обновления списка доменов используйте:

   ```bash
   ./update_domains.sh
   ```
