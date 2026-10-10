#!/bin/bash

IPS=()
while IFS= read -r ip || [[ -n "$ip" ]]; do
    ip=${ip%$'\r'}
    [[ -z "$ip" || "$ip" == \#* ]] && continue
    IPS+=("$ip")
done < "./input_sni_proxy_ips.txt"

if [[ ${#IPS[@]} -eq 0 ]]; then
    echo "Список IP пуст: ./input_sni_proxy_ips.txt" >&2
    exit 1
fi

echo '### dns.malw.link: hosts file' > ../hosts
echo -e "# Последнее обновление: $(date '+%d %B %Y')\n" >> ../hosts

tr -d '\r' < ../lists/hosts.txt >> ../hosts
echo >> ../hosts

declare -A checked_domains
declare -A domain_ips

while read -r section; do
    sec_name=$(echo "$section" | jq -r '.section')
    force_ip=$(echo "$section" | jq -r '.force_ip // ""')
    echo -e "\n# $sec_name" >> ../hosts

    for domain in $(echo "$section" | jq -r '.domains | if type=="array" then .[] else . end'); do
        if [[ -n "$force_ip" ]]; then
            echo "Используется $force_ip для $domain"
            echo "$force_ip $domain" >> ../hosts
            domain_ips["$domain"]=$force_ip
        else
            found=0
            echo "Проверка $domain..."
            for ip in "${IPS[@]}"; do
                if curl -s -o /dev/null -m 15 "https://$domain" --connect-to "::$ip"; then
                    echo "$ip $domain" >> ../hosts
                    echo "Найден $ip для $domain"
                    domain_ips["$domain"]=$ip
                    found=1
                    break
                fi
            done

            if [[ $found -eq 0 ]]; then
                echo "!!! Не найден рабочий IP для $domain"
            fi
        fi
        checked_domains["$domain"]=1
    done
done < <(jq -c '.[]' input_domains.json)

echo -e '\n# Блокировка' >> ../hosts
tr -d '\r' < ../lists/garbage.txt | sed 's/^/0.0.0.0 /' >> ../hosts

echo -e "\n\n### dns.malw.link: end hosts file" >> ../hosts

default_ip=$(tr -d '\r' < ../dns-server/sni_proxy_ips.txt | grep -v ":" | head -n1)

declare -A seen_domains
> ../adguard.txt

while read -r ip domain; do
    if [[ -n "$domain" && -z "${seen_domains[$domain]}" ]]; then
        echo "|$domain^\$dnsrewrite=$ip" >> ../adguard.txt
        seen_domains["$domain"]=1
    fi
done < <(tr -d '\r' < ../lists/hosts.txt)

while read -r section; do
    force_ip=$(echo "$section" | jq -r '.force_ip // ""')
    while read -r domain; do
        if [[ -z "${seen_domains[$domain]}" ]]; then
            if [[ -n "$force_ip" ]]; then
                echo "|$domain^\$dnsrewrite=$force_ip" >> ../adguard.txt
                seen_domains["$domain"]=1
            elif [[ -n "${domain_ips[$domain]}" ]]; then
                echo "|$domain^\$dnsrewrite=${domain_ips[$domain]}" >> ../adguard.txt
                seen_domains["$domain"]=1
            elif [[ -n "${checked_domains[$domain]}" ]]; then
                :
            else
                found=0
                echo "Проверка $domain (AdGuard)..."
                for ip in "${IPS[@]}"; do
                    if curl -s -o /dev/null -m 15 "https://$domain" --connect-to "::$ip"; then
                        echo "|$domain^\$dnsrewrite=$ip" >> ../adguard.txt
                        seen_domains["$domain"]=1
                        echo "Найден $ip для $domain (AdGuard)"
                        found=1
                        break
                    fi
                done

                if [[ $found -eq 0 ]]; then
                    echo "!!! Не найден рабочий IP для $domain"
                fi
            fi
        fi
    done < <(echo "$section" | jq -r '.domains | if type=="array" then .[] else . end')
done < <(jq -c '.[]' input_domains.json)

while read -r domain; do
    if [[ -n "$domain" && -z "${seen_domains[$domain]}" ]]; then
        echo "||$domain^\$dnsrewrite=$default_ip" >> ../adguard.txt
        seen_domains["$domain"]=1
    fi
done < <(tr -d '\r' < ../lists/domains_with_subdomains.txt)

echo >> ../adguard.txt

while read -r domain; do
    if [[ -n "$domain" && -z "${seen_domains[$domain]}" ]]; then
        found=0
            echo "Проверка $domain (AdGuard)..."
        for ip in "${IPS[@]}"; do
            if curl -s -o /dev/null -m 15 "https://$domain" --connect-to "::$ip"; then
                echo "|$domain^\$dnsrewrite=$ip" >> ../adguard.txt
                seen_domains["$domain"]=1
                    echo "Найден $ip для $domain (AdGuard)"
                found=1
                break
            fi
        done

        if [[ $found -eq 0 ]]; then
            echo "!!! Не найден рабочий IP для $domain"
        fi
    fi
done < <(tr -d '\r' < ../lists/domains.txt)

while read -r domain; do
    if [[ -n "$domain" && -z "${seen_domains[$domain]}" ]]; then
        echo "|$domain^\$dnsrewrite=0.0.0.0" >> ../adguard.txt
        seen_domains["$domain"]=1
    fi
done < <(tr -d '\r' < ../lists/garbage.txt)