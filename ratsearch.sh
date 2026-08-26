#!/bin/sh
#requires: jq fzf html2text zim-tools
#zimdump list wikipedia.zim > index
DATABASE="./wikipedia.zim"
INDEX="./index"
ENDPOINT="localhost:8080" #LLM API endpoint, e.g. "api.openai.com"

SYSTEM='
You are a helpful assistant. 

## Skills

You can read Wikipedia articles; use this when factual info is directly requested. Use the `read_article` tool with an article title to read it.
'
# ---- Tools ---- 
#I like making my code tidy with manual ---- Section Headers ---- , thank you very much.
conversation="$( #initialize conversation + tool definition
    jq -n --arg system "$SYSTEM" '{
        "messages":[{"role": "system", "content": $system}], 
        "tools":[{"type": "function","function": {"name": "read_article","description": "read a wikipedia article","parameters": 
        {"properties": {"title": {"type": "string","description": "article title"}},"required": ["title"]}}}],
        "tool_choice": "auto"}'
)"
read_article() { #$1 = title query
    title="$(echo "$1" | tr ' ' '_')"
    details="$(zimdump list --details --url "$title" "$DATABASE" 2>&1)"
    if [ "$details" != "Entry not found" ]; then echo "Article:" #real article
        index="$(echo "$details" | grep "redirect index" | grep -oE '[0-9]+$')" #look if there's a redirect index    
        test -z "$index" && index="$(echo "$details" | grep "idx" | grep -oE '[0-9]+$')" #otherwise use the main index
        zimdump show --idx "$index" "$DATABASE" 2>&1 | html2text | head -c 65535 #trim at 65k characters
    else echo "Article not found. Related articles:" #invalid title, so search for related
        cat "$INDEX" | fzf -f "$1" | head -n 20 | tr '_' ' ' #desnake for ease of model understanding 
    fi
} #remember, if your tool outputs a well-made error the model can adapt and correct itself

# ---- Conversation ----
loop() {
    PING="$(curl -sS http://"$ENDPOINT"/v1/models)" || die #report curl errors
    echo "$PING" | grep "error" >/dev/null && echo "Endpoint error:" && jq -n --argjson error "$PING" '$error' && return 1 #report http errors
    printf "%s\n%s\n%s\n%s\r" "ratsearch <-3,,~~" "$DATABASE" "$(jq -nr --argjson ping "$PING" '$ping.models[0].name')" "----------------------"
    turn="user"; while :; do #main conversation loop
        test "$turn" = "user" && listen && turn="assistant" #record user message    
        printf "\n%s\n" "  ===== AGENT =====" #agent banner
        ratspin & spinner=$! #animation while waiting for response
        trap 'kill "$spinner" 2>/dev/null; printf "\n"' EXIT; trap 'exit 130' INT TERM #kill spinner if ^C during animation
        parse "$(query)" #send conversation and process response
        sleep 1
    done
}
listen() { printf "\n%s\n" "  <><><> USER <><><>" #user banner
    read -r input #waits for user input
    conversation="$(printf "%s" "$conversation" | jq --arg content "$input" \
        '.messages += [{"role": "user", "content": $content}]')"; #push user message into conversation
}
query() { printf "%s" "$conversation" \
    | curl -s --request POST --url http://"$ENDPOINT"/v1/chat/completions --header "Content-Type: application/json" --data @- \
    | jq '.choices[0].message' 
} #$conversation can get very long, so it needs to be piped into curl with --data @- to avoid ARG_MAX
parse() { kill "$spinner"; wait $! 2>/dev/null; printf "\033[2K\r" #stop and clear spinner
    test "$1" = "null" && echo "Context size exceeded :(" && die #usually the cause of a failed response
    conversation="$(printf "%s" "$conversation" | jq --argjson message "$1" \
        '.messages += [$message | del(.reasoning_content?)]')"; #add agent response to conversation, strip thinking
    
    #show reasoning and response
    reasoning="$(jq -nr --argjson message "$1" '$message.reasoning_content // ""')"
    response="$(jq -nr --argjson message "$1" '$message.content // ""')"
    test -n "$reasoning" && printf "\033[3m\033[90m%s\n%s\n%s\n\033[0m" "----- Reasoning -----" "$reasoning" "---------------------"
    test -n "$response" && printf "%s\n" "$(echo "$response" | sed ':a;$!N;$!ba;:b;s/\*\*/\x1b[1m/;s/\*\*/\x1b[22m/;tb')" #apply bold
    
    #evaluate tool calls
    if [ "$(jq -n --argjson message "$1" '$message | has("tool_calls")')" = "false" ]; then turn="user" #no tool calls, return to user
    else #message has tool calls
        calls="$(jq -n --argjson message "$1" -r '$message.tool_calls | length')"
        i=0; while [ "$i" -le $((calls - 1)) ]; do #for each call; there can be multiple!
            id="$(jq -nr --argjson message "$1" --argjson i "$i" '$message.tool_calls[$i].id')"
            name="$(jq -nr --argjson message "$1" --argjson i "$i" '$message.tool_calls[$i].function.name')"
            arguments="$(jq -nr --argjson message "$1" --argjson i "$i" '$message.tool_calls[$i].function.arguments | fromjson | .[]')"   
            result="$(read_article "$arguments")" #will crash if too long, but read_article is capped at 60k characters to prevent this
            printf "%s\n\033[3m\033[90m%s\n\033[0m" "[tool call]: $name | $arguments" "$(echo "$result" | head -n 10)"
            conversation="$(printf "%s" "$conversation" | jq --arg id "$id" --arg result "$result" \
                '.messages += [{"role": "tool", "tool_call_id": $id, "content": $result}]')" #add tool result to conversation
        i=$((i + 1)); done 
    fi
}
ratspin() { while :; do #spinner animation + generation status reporting
        status="$(curl -sS http://"$ENDPOINT"/slots)" || die #problems happen if multiple models are active at the same time
        prefill="$(jq -n --argjson status "$status" '($status[] | select(.is_processing) | .n_prompt_tokens_processed) // 0')"
        generated="$(jq -n --argjson status "$status" '($status[] | select(.is_processing) | .next_token[0].n_decoded) // 0')"
            if [ "$generated" != "0" ]; then printf "\r%s" "$generated Thinking..." #generating response
            elif [ "$prefill" != "0" ]; then printf "\r%s" "$prefill Reading..." #prefilling
            else printf "\r%s" "Processing..."; fi #tokenizing (?)
        if [ "$rat" != "  ~~=8>" ]; then rat="  ~~=8>"; else printf "      "; rat="<8=~~"; fi
        for i in $(echo "1 2 3 4 5 6"); do printf "%s\b\b\b\b\b\b\033[P" "$rat"; sleep 0.1; done
    done #^twoliner spinner animation, ish. relies on the \r above. also, sleep 0.1 is not posix :^V
}
die() { kill "$$"; exit 1; } #stop the script

#oops I gained some space after the refactor

loop #go!
