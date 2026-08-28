Teeny-tiny RAG tools; ratsearch is 100 lines of code and batsearch is just 30! Coded by hand <3

[writeup](https://gbkorr.github.io/r-bites/ratsearch/ratsearch.html)

### Batsearch "2'
CLI tool for oneshot prompts; outputs LLM response to stdout. Lets model perform web searches using w3m+duckduckgo. 

Requires: `curl jq w3m`  
Usage: `sh batsearch.sh [--verbose] PROMPT [ENDPOINT]`

--verbose logs reasoning and search queries to stderr. Default endpoint = "localhost:8080" for llama-server

### Ratsearch <-3,,~~
Interactive chat, lets model search and read articles from an offline Wikipedia archive.

Requires: `curl jq fzf html2text zim-tools`  
Setup:

- download a .zim wikipedia archive (e.g. `wikipedia_en_all_nopic` from [https://dumps.wikimedia.org/other/kiwix/zim/wikipedia/](https://dumps.wikimedia.org/other/kiwix/zim/wikipedia/)).
- put `ratsearch.sh` and your wikipedia zim in a folder
- rename your wikipedia zim to `wikipedia.zim`
- run `zimdump list wikipedia.zim > index` to generate the list of titles

Usage: `sh ratsearch.sh`

Ratsearch may be receiving an update soon :)
