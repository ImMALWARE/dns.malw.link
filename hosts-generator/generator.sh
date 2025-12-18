#!/bin/bash

mapfile -t IPS < "./input_sni_proxy_ips.txt"

echo '### dns.malw.link: hosts file' > ../hosts
echo -e "# Последнее обновление: $(date '+%d %B %Y')\n" >> ../hosts

cat ../lists/hosts.txt >> ../hosts
echo >> ../hosts

jq -c '.[]' input_domains.json | while read -r section; do
    echo -e "\n# $(echo "$section" | jq -r '.section')" >> ../hosts

    for domain in $(echo "$section" | jq -r '.domains | if type=="array" then .[] else . end'); do
        found=0
        for ip in "${IPS[@]}"; do
            echo "Проверка $domain на $ip..."
            if curl -s -o /dev/null -m 15 "https://$domain" --connect-to "::$ip"; then
                echo "$ip $domain" >> ../hosts
                found=1
                break
            fi
        done

        if [[ $found -eq 0 ]]; then
            echo "!!! Не найден рабочий IP для $domain"
        fi
    done
done

echo -e '\n# Блокировка' >> ../hosts
sed 's/^/0.0.0.0 /' ../lists/garbage.txt >> ../hosts

echo -e "\n\n### dns.malw.link: end hosts file" >> ../hosts

default_ip=$(grep -v ":" ../dns-server/sni_proxy_ips.txt | head -n1)

awk '{print "|" $2 "^$dnsrewrite=" $1}' ../lists/hosts.txt > ../adguard.txt

sed "s/^/||/; s/$/^\$dnsrewrite=$default_ip/" ../lists/domains_with_subdomains.txt >> ../adguard.txt
echo >> ../adguard.txt

while read -r domain; do
    found=0
    for ip in "${IPS[@]}"; do
        echo "Проверка $domain на $ip..."
        if curl -s -o /dev/null -m 15 "https://$domain" --connect-to "::$ip"; then
            echo "|$domain^"'$dnsrewrite='"$ip" >> ../adguard.txt
            found=1
            break
        fi
    done
    if [[ $found -eq 0 ]]; then
        echo "!!! Не найден рабочий IP для $domain"
    fi
done < ../lists/domains.txt

sed 's/^/|/; s/$/^\$dnsrewrite=0.0.0.0/' ../lists/garbage.txt >> ../adguard.txt