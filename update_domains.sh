docker-compose down
rm logs -rf
curl -L -o "proxy.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/refs/heads/master/domains.txt"
curl -L -o "proxy_with_subdomains.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/refs/heads/master/domains_with_subdomains.txt"
docker-compose up -d --build