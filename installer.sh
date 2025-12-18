#!/bin/bash

dependencies=(curl dig docker docker-compose nano socat)
ports=(53 80 443 853 8443 9339 30000)

for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Ошибка: На сервере не установлен '$cmd'. Установите его и снова запустите установщик."
        exit 1
    fi
done

for port in "${ports[@]}"; do
    if ss -lntu | grep -qE ":$port\s+"; then
        echo "Порт $port уже используется другим процессом. Освободите этот порт и снова запустите установщик."
        exit 1
    fi
done

rm -rf hosts-generator hosts adguard.txt LICENSE README.md

echo "Настроить DNS-сервер на этом сервере? [y/n]"
read dns_choice

IPv4=$(curl -s4m3 v4.ip.wtf)
IPv6=$(curl -s6m3 v6.ip.wtf)

if [[ "$dns_choice" =~ ^[yY]$ ]]; then
    echo "Нужны ли DNS over HTTPS и DNS over TLS? Для этого вы должны привязать ваш домен к IP сервера: $(printf "%s %s" "$IPv4" "$IPv6" | xargs) [y/n]"
    read dot_choice
    if [[ "$dot_choice" =~ ^[yY]$ ]]; then
        echo "Введите ваш домен для сертификатов (например, dns.example.com): "
        read domain_name
        echo "Автоматически получить новые сертификаты? [y] или ожидать сертификаты в папке ./dns-server/certs? (fullchain.cer и key.key) [n]"
        read cert_choice
        if [[ "$cert_choice" =~ ^[yY]$ ]]; then
            if ! [ -d ~/.acme.sh ]; then
                echo "Установка acme.sh"
                curl https://get.acme.sh | sh
            fi
            if ! [[ "$(dig +short A "$domain_name")" == "$IPv4" ]] || ! [[ "$(dig +short AAAA "$domain_name")" == "$IPv6" ]]; then
                echo "Домен $domain_name не указывает на IP-адреса этого сервера ($(printf "%s %s" "$IPv4" "$IPv6" | xargs)). Нажмите Enter, чтобы продолжить. НО СКОРЕЕ ВСЕГО, ПОЛУЧЕНИЕ СЕРТИФИКАТОВ НЕ ВЫПОЛНИТСЯ!"
                read
            fi

            CERTS_PATH="$(pwd)/dns-server/certs"
            ~/.acme.sh/acme.sh --issue -d "$domain_name" --standalone --pre-hook "iptables -I INPUT -p tcp --dport 80 -j ACCEPT; docker stop sni_proxy || true; docker stop dnsdist || true" --post-hook "iptables -D INPUT -p tcp --dport 80 -j ACCEPT; docker start sni_proxy; docker start dnsdist" --server letsencrypt
            ~/.acme.sh/acme.sh --install-cert -d "$domain_name" --fullchain-file "$CERTS_PATH/fullchain.cer" --key-file "$CERTS_PATH/key.key" --reloadcmd "docker restart dnsdist; docker restart sni_proxy"
            iptables -D INPUT -p tcp --dport 80 -j ACCEPT
        fi
    fi
fi

echo "Нужен ли SNI Proxy на этом сервере? ($(printf "%s %s" "$IPv4" "$IPv6" | xargs)) [y/n] "
read sni_proxy_choice
if [[ "$sni_proxy_choice" =~ ^[yY]$ ]]; then
    if [[ "$dot_choice" =~ ^[yY]$ ]]; then
        sed -i 's/- "443:443\/tcp"/- "127.0.0.1:8443:443\/tcp"/' dns-server/docker-compose.yml
        sed -i "s|include /etc/nginx/whitelist_domains.conf;|$domain_name 2;\n\t\tinclude /etc/nginx/whitelist_domains.conf;|" sni-proxy/nginx.conf
        sed -i "s|\"1:0\"|\"2:0\"   127.0.0.1:8443;\n\t\t\"1:0\"|" sni-proxy/nginx.conf
    fi
else
    echo "Сейчас в редакторе введите IP-адреса SNI Proxy серверов, разделённых новыми строками и сохраните файл (Ctrl + S, затем Ctrl + X). Если есть и IPv4 и IPv6, лучше ввести оба из них. Нажмите Enter для продолжения."
    read
    nano ./dns-server/sni_proxy_ips.txt
fi

echo "Нужен ли прокси для игры mo.co? [y/n]"
read moco_choice

echo "Нужен ли прокси для одной из игр Supercell? Все они, кроме mo.co используют TCP на порту 9339. Nginx не может узнать, к какой игре относится запрос, поэтому на одном сервере может быть только прокси для одной игры."
echo "1. Не нужен"
echo "2. Clash Royale"
echo "3. Clash of Clans"
echo "4. Brawl Stars"
echo "5. Squad Busters"
echo "[1-5]:"
read supercell_choice

add_game_to_nginx() {
    sed -i '$d' ./sni-proxy/nginx.conf
    echo -e "    server {\n        listen $1;\n        proxy_pass $2:$1;\n        proxy_timeout 5h;\n    }\n}" >> ./sni-proxy/nginx.conf
}

change_game_in_hosts() {
    sed -i "s|^.*[[:space:]]$1|$IPv4 $1|" ./lists/hosts.txt
}

if [[ ! "$sni_proxy_choice" =~ ^[yY]$ ]] && { [[ "$moco_choice" =~ ^[yY]$ ]] || [[ "$supercell_choice" =~ ^[2-5]$ ]]; }; then
    cat > ./sni-proxy/nginx.conf <<EOF
worker_processes auto;
worker_rlimit_nofile 65535;
error_log /dev/stderr warn;

events {
    worker_connections 16384;
    use epoll;
    multi_accept on;
}

stream {
    log_format basic 'From \$remote_addr \$protocol \$status to \$ssl_preread_server_name \$upstream_addr sent \$bytes_sent b, received \$bytes_received b in \$session_time';
    LOG_SETTING;

    server {
        listen 127.0.0.1:444;
    }
}
EOF
fi

if [[ "$moco_choice" =~ ^[yY]$ ]]; then
    add_game_to_nginx "30000" "game.mocogame.com"
    change_game_in_hosts "game.mocogame.com"
    game_added=true
fi

case "$supercell_choice" in
    2)
        add_game_to_nginx "9339" "game.clashroyaleapp.com"
        change_game_in_hosts "game.clashroyaleapp.com"
        game_added=true
        ;;
    3)
        add_game_to_nginx "9339" "gamea.clashofclans.com"
        change_game_in_hosts "gamea.clashofclans.com"
        game_added=true
        ;;
    4)
        add_game_to_nginx "9339" "game.brawlstarsgame.com"
        change_game_in_hosts "game.brawlstarsgame.com"
        game_added=true
        ;;
    5)
        add_game_to_nginx "9339" "game.squadbustersgame.com"
        change_game_in_hosts "game.squadbustersgame.com"
        game_added=true
        ;;
esac

if [ "$game_added" = true ]; then
    sed -i 's|curl -L -o "hosts.txt"|# curl -L -o "hosts.txt"|' ./control.sh
fi

echo "Нужна ли настройка чёрного списка IP-адресов, которым будет отказано в соединении с DNS и SNI Proxy? Нужно будет ввести URL со списком IP-адресов с разделением через новую строку. Его можно разместить, например, на Pastebin. [y/n]"
read banned_ips_choice

if [[ "$banned_ips_choice" =~ ^[yY]$ ]]; then
    echo "Введите URL со списком IP-адресов: "
    read banned_ips_url
    sed -i "s|^BANNED_IPS_URL=.*|BANNED_IPS_URL=$banned_ips_url|" ./.env
else
    sed -i "s|^BANNED_IPS_URL=.*|BANNED_IPS_URL=|" ./.env
fi

./control.sh update

if [[ "$dns_choice" =~ ^[yY] ]]; then
    echo "Запуск dnsdist"
    cd dns-server && docker-compose up -d && cd ..
else
    rm -rf dns-server
fi

if [[ "$sni_proxy_choice" =~ ^[yY]$ ]] || [ "$game_added" = true ]; then
    echo "Запуск nginx"
    cd sni-proxy && docker-compose up -d && cd ..
else
    rm -rf sni-proxy
fi

echo "Нужен ли Promtail для сбора логов в Grafana? [y/n] "
read promtail_choice

if [[ "$promtail_choice" =~ ^[yY]$ ]]; then
    echo "Создайте аккаунт на https://grafana.com и получите данные в My Account (grafana.com, не *.grafana.net) -> слева название организации -> Loki -> Send Logs."
    echo "Введите URL (в самом верху страницы Grafana Data Source settings) БЕЗ https://"
    read promtail_url
    echo "Введите User (там же, сверху):"
    read promtail_user
    echo "Введите токен. В середине страницы Sending Logs to Grafana Cloud using Promtail -> кнопка Generate now:"
    read promtail_token
    echo "Введите имя сервера (будет в host в логах):"
    read promtail_server_name

    sed -i "s|^PROMTAIL_SERVER_NAME=.*|PROMTAIL_SERVER_NAME=$promtail_server_name|" .env
    sed -i "s|^PROMTAIL_TOKEN=.*|PROMTAIL_TOKEN=$promtail_token|" .env
    sed -i "s|^PROMTAIL_URL=.*|PROMTAIL_URL=$promtail_url|" .env
    sed -i "s|^PROMTAIL_USER_ID=.*|PROMTAIL_USER_ID=$promtail_user|" .env

    echo "Запуск promtail"
    cd promtail && docker-compose up -d && cd ..
else
    rm -rf promtail
fi
echo "Установка завершена. О недочётах пишите в Issues. По вопросам пишите на contact@malw.link или в чат https://t.me/immalware_chat"
rm installer.sh