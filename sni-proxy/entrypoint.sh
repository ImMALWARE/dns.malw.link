echo "" > /etc/nginx/whitelist_domains.conf
echo "" > /etc/nginx/whitelist_domains_with_subdomains.conf
echo "" > /etc/nginx/whitelist_custom.conf
echo "" > /etc/nginx/banned_ips.conf
cp /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf

if [ -f /etc/nginx/lists/banned_ips.txt ]; then
    awk '!/^#/ && NF {print $0 " 1;"}' /etc/nginx/lists/banned_ips.txt > /etc/nginx/banned_ips.conf
fi

if [ -f /etc/nginx/lists/domains.txt ]; then
    awk 'NF {print $0 " 1;"}' /etc/nginx/lists/domains.txt > /etc/nginx/whitelist_domains.conf
fi

if [ -f /etc/nginx/lists/domains_with_subdomains.txt ]; then
    awk 'NF {
        gsub(/\./, "\\\\.");
        print "~(^|\\\\.)" $0 "$ 1;"
    }' /etc/nginx/lists/domains_with_subdomains.txt > /etc/nginx/whitelist_domains_with_subdomains.conf
fi

if [ -f /etc/nginx/lists/custom.txt ]; then
    awk 'NF {
        gsub(/\./, "\\\\.");
        print "~(^|\\\\.)" $0 "$ 1;"
    }' /etc/nginx/lists/custom.txt > /etc/nginx/whitelist_custom.conf
fi

if [ "$LOG_ALL" != "true" ]; then
    sed -i 's|LOG_SETTING;|access_log off;|' /etc/nginx/nginx.conf
else
    sed -i 's|LOG_SETTING;|access_log /dev/stdout basic;|' /etc/nginx/nginx.conf
fi

nginx -t

exec nginx -g "daemon off;"