#!/bin/sh
verbose="$(test -n "$(echo "$@" | grep "\-\-verbose")" && echo true)" && shift
ENDPOINT="${2:-localhost:8080}"
SYSTEM="$(echo "You are a helpful assistant.\n\nToday's date: $(date)\n\n## Skills\n\nYou can access the web with the websearch tool.")"
conv="$(jq -n --arg system "$SYSTEM" --arg prompt "$1" '{
    "messages":[{"role": "system", "content": $system},{"role": "user", "content": $prompt}], 
    "tools":[{"type": "function","function": {"name": "websearch","description": "search the web","parameters": 
        {"properties": {"search query": {"type": "string","description": "keywords or url"}},"required": ["search query"]}}}],
    "tool_choice": "auto"}')"
websearch() { #if a url is in the keywords, access it directly. Qwen likes to prepend "site:", so we have to remove that
    url="$(echo "$1" | grep -oE '[^ ]*\.[^ ]*' | head -1 | sed 's/site://g')"; test -z "$url" && url="duckduckgo.com/$(echo "$1" | tr ' ' '+')"
    w3m -dump -no-cookie -o accept_encoding=identity "$url" | head -c 65535
}
loop() { while :; do parse "$(query)"; sleep 1; done; }
query() { printf "%s" "$conv" \
    | curl -sS --request POST --url http://"$ENDPOINT"/v1/chat/completions --header "Content-Type: application/json" --data @- \
    | jq '.choices[0].message'
}
parse() { test -z "$1" && kill "$$"
    conv="$(printf "%s" "$conv" | jq --argjson msg "$1" '.messages += [$msg | del(.reasoning_content?)]')"
    test $verbose && jq -nr --argjson msg "$1" '"[reasoning]: \($msg.reasoning_content?)"' >&2
	if [ "$(jq -n --argjson msg "$1" '$msg | has("tool_calls")')" = "false" ]; then 
        jq -nr --argjson msg "$1" '$msg.content'; kill -USR1 "$$"
	else IFS='~'; for call in $(jq -nr --argjson msg "$1" '$msg.tool_calls[]  | "\(.)~"'); do
        args="$(jq -nr --argjson call "$call" '$call.function.arguments | fromjson | .[]')"; test $verbose && echo "[websearch]: $args" >&2
		conv="$(printf "%s" "$conv" | jq --argjson call "$call" --arg result "$(websearch "$args")" \
			'.messages += [{"role": "tool", "tool_call_id": $call.id, "content": $result}]')"
	done; fi
}
test -z "$1" && echo "Usage: sh batsearch.sh [--verbose] PROMPT [ENDPOINT]" && exit 2; trap 'exit 1' TERM; trap 'exit 0' USR1; loop
