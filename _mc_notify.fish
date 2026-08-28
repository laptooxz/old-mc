function _mc_notify --description "Send notification with sound"
    set title $argv[1]
    set msg $argv[2]
    set sound_name $argv[3]

    if command -v notify-send >/dev/null
        hostenv notify-send -a laptooMC -i minecraft "$title" "$msg" >/dev/null 2>&1 &
    end

    if test -n "$sound_name" && not set -q _mc_notify_nosound
        switch $sound_name
            case start
                set sound ~/mc/library/sounds/block/beacon/activate.ogg
            case stop
                set sound ~/mc/library/sounds/block/beacon/deactivate.ogg
            case ready
                set sound ~/mc/library/sounds/random/levelup.ogg
            case join
                set sound ~/mc/library/sounds/note/pling.ogg
            case leave
                set sound ~/mc/library/sounds/random/break.ogg
            case death
                set sound ~/mc/library/sounds/mob/wither/spawn.ogg
            case chunky-start
                set sound ~/mc/library/sounds/random/orb.ogg
            case chunky-finish
                set sound ~/mc/library/sounds/item/goat_horn/call0.ogg
            case window-attention
                set sound ~/mc/library/sounds/item/goat_horn/call1.ogg
            case message-new-instant
                set sound ~/mc/library/sounds/mob/wither/spawn.ogg
            case '*'
                set sound "$HOME/mc/library/sounds/random/orb.ogg"
        end
        if test -f "$sound"
            hostenv paplay "$sound" >/dev/null 2>&1 &
        end
    end

    if command -v ntfy-push >/dev/null
        ntfy-push mc "$title" "$msg" &
    end
end
