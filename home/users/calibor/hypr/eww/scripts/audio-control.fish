#!/usr/bin/env fish

set -l command $argv[1]
# other 'subcommands', etc.
if [ "$command" = art ]
    set -l art_thumb_cache "$HOME/.cache/music-thumbs"
    if not [ -d "$art_thumb_cache" ]
        mkdir -p "$art_thumb_cache"
    end
    set -l art_url (playerctl metadata mpris:artUrl)
    if string match -q "https://*" "$art_url"
        set -l art_name (basename "$art_url")
        set -l art_path "$art_thumb_cache/$art_name"
        if not [ -f "$art_path" ]
            curl -fLo "$art_path" "$art_url"
        end
        echo "$art_path"
    else
        echo "$art_url"
    end
end
