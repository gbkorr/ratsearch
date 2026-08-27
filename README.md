Teeny-tiny RAG tools; ratsearch is 100 lines of code and batsearch is just 30! 

[writeup](https://gbkorr.github.io/r-bites/ratsearch/ratsearch.html)

### Batsearch "2'
Lets model perform web searches.  
CLI tool for oneshot prompts; outputs LLM response to stdout. --verbose logs reasoning and websearches to stderr

Usage: 

`sh batsearch.sh [--verbose] PROMPT [ENDPOINT]`

### Ratsearch <-3,,~~
Interactive chat, lets model search and read articles from an offline Wikipedia archive

Setup:

- download a .zim wikipedia archive (e.g. `wikipedia_en_all_nopic` from [https://dumps.wikimedia.org/other/kiwix/zim/wikipedia/](https://dumps.wikimedia.org/other/kiwix/zim/wikipedia/)).
- put `ratsearch.sh` and your wikipedia zim in a folder
- rename your wikipedia zim to `wikipedia.zim`
- run `zimdump list wikipedia.zim > index` to generate the list of titles
- run `sh ratsearch.sh` to use ratsearch

