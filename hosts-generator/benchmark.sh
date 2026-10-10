#!/bin/bash

set -u

INPUT_FILE="input_sni_proxy_ips.txt"
URLS=(
	"https://chatgpt.com/unauth-mweb/assets/a-D89x2zeC.js"
	"https://gemini.google.com/"
	"https://claude.ai/i18n/ru.json"
)
LABELS=(ChatGPT Gemini Claude)
IPS=()

while IFS= read -r ip || [[ -n "$ip" ]]; do
	ip=${ip%$'\r'}
	[[ -z "$ip" ]] && break
	IPS+=("$ip")
done < "$INPUT_FILE"

if [[ ${#IPS[@]} -eq 0 ]]; then
	echo "IP-адреса не найдены" >&2
	exit 1
fi

RESULTS_FILE=$(mktemp)
TEMP_INPUT=""
trap 'rm -f "$RESULTS_FILE"; [[ -z "$TEMP_INPUT" ]] || rm -f "$TEMP_INPUT"' EXIT

for ip in "${IPS[@]}"; do
	failures=0
	total=0
	times=()

	for url in "${URLS[@]}"; do
		echo "Проверка $ip: $url"
		if result=$(curl -sS -L -o /dev/null \
			--connect-timeout 10 --max-time 60 \
			--connect-to "::$ip" \
			-w '%{time_total}' "$url" 2>/dev/null); then
			elapsed=$result
			marker=""
		else
			elapsed=${result:-60}
			marker="!"
			((failures += 1))
		fi

		if [[ ! "$elapsed" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
			elapsed=60
		fi

		total=$(awk -v total="$total" -v elapsed="$elapsed" 'BEGIN { printf "%.6f", total + elapsed }')
		times+=("$(awk -v elapsed="$elapsed" -v marker="$marker" 'BEGIN { printf "%.3f%s", elapsed, marker }')")
	done

	average=$(awk -v total="$total" -v count="${#URLS[@]}" 'BEGIN { printf "%.3f", total / count }')
	printf '%s\t%d\t%s\t%s\t%s\t%s\n' \
		"$ip" "$failures" "$average" "${times[0]}" "${times[1]}" "${times[2]}" >> "$RESULTS_FILE"
done

sort -t $'\t' -k2,2n -k3,3n -o "$RESULTS_FILE" "$RESULTS_FILE"

TEMP_INPUT=$(mktemp "${INPUT_FILE}.XXXXXX")
{
	awk -F '\t' '{ print $1 }' "$RESULTS_FILE"
	sed -n '/^[[:space:]]*$/,$p' "$INPUT_FILE"
} > "$TEMP_INPUT"
mv "$TEMP_INPUT" "$INPUT_FILE"
TEMP_INPUT=""

printf '%-18s %8s %9s %10s %10s %10s\n' "IP" "Ошибки" "Среднее, с" "${LABELS[0]}" "${LABELS[1]}" "${LABELS[2]}"
	awk -F '\t' '{ printf "%-18s %8d %9.3f %10s %10s %10s\n", $1, $2, $3, $4, $5, $6 }' "$RESULTS_FILE"