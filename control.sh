#!/bin/bash

export $(grep -v '^#' .env | xargs)

for action in "$@"; do
    case "$action" in
        update)
            echo "Обновление списков"
            cd lists
            curl -L -o "domains.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/master/lists/domains.txt"
            curl -L -o "domains_with_subdomains.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/master/lists/domains_with_subdomains.txt"
            curl -L -o "garbage.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/master/lists/garbage.txt"
            curl -L -o "hosts.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/master/lists/hosts.txt"
            if [ -n "$BANNED_IPS_URL" ]; then
                curl -L -o "banned_ips.txt" "$BANNED_IPS_URL"
            fi
            cd ..
            echo "Завершено"
        ;;
        restart)
            if [ -d "dns-server" ]; then
                echo "Перезапуск dnsdist"
                cd dns-server && docker-compose down && docker-compose up -d && cd ..
            fi
            if [ -d "sni-proxy" ]; then
                echo "Перезапуск nginx"
                cd sni-proxy && docker-compose down && docker-compose up -d && cd ..
            fi
            if [ -d "promtail" ]; then
                echo "Перезапуск promtail"
                cd promtail && docker-compose down && docker-compose up -d && cd ..
            fi
        ;;
        logall)
            sed -i "s|^LOG_ALL=.*|LOG_ALL=true|" ./.env
            echo "Логирование всех запросов включено."
        ;;
        nolog)
            sed -i "s|^LOG_ALL=.*|LOG_ALL=false|" ./.env
            echo "Логирование всех запросов отключено."
        ;;
        checkgarbage)
            echo "Начинаю чистку garbage.txt"
            temp_file=$(mktemp)

            check_and_filter() {
                if curl -s -o /dev/null -m 5 "https://$1" || curl -s -o /dev/null -m 3 "http://$1"; then
                    echo "$1"
                    echo -e "\e[32m[ALIVE]\e[0m $1" >&2
                else
                    echo -e "\e[31m[DELETE]\e[0m $1" >&2
                fi
            }
            export -f check_and_filter
            grep -vE '^\s*#|^\s*$' lists/garbage.txt | tr -d '\r' | xargs -P 20 -I {} bash -c 'check_and_filter "{}"' > "$temp_file"
            mv "$temp_file" lists/garbage.txt
            echo "Нерабочие домены удалены из garbage.txt"
        ;;
        *)
            echo "Неизвестная команда: $action"
        ;;
    esac
done