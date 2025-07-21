# dns.malw.link

Здесь 4 ветки
1. master - описание, файл hosts, mobileconfig
2. dns-server - DNS сервер
3. sni-proxy - SNI Proxy
4. web - Веб-страницы (info.dns.malw.link)

## Как всё это запустить у себя?
Предполагается, что DNS-севрер и SNI Proxy находятся на разных серверах.

### Для DNS-сервера
1. Убедитесь, что у вас установлен Docker и Docker Compose. Если не знаете как - спросите у ChatGPT.
2. `git clone -b dns-server --single-branch https://github.com/ImMALWARE/dns.malw.link`
3. `cd dns.malw.link`
4. Замените IP-адреса SNI Proxy в файле `dnsdist.conf` на адреса своих серверов. Нужные для этого строки там прокомментированы.
5. Если вам нужен DNS over TLS и DNS over HTTPS, поместите сертификаты для них в папку `certs` (fullchain.cer и key.key). Если нет, закомментируйте строки 4 и 5 в `dnsdist.conf` и 10, 11, 17 в `docker-compose.yml`.
6. `docker-compose up -d`

### Для SNI Proxy
1. Убедитесь, что у вас установлен Docker и Docker Compose. Если не знаете как - спросите у ChatGPT.
2. `git clone -b sni-proxy --single-branch https://github.com/ImMALWARE/dns.malw.link`
3. `cd dns.malw.link`
4. `docker-compose up -d`
