function _mc_kick_bots --description 'Kick running bots bound to this server port'
    set -l dir $argv[1]
    set -l srvport (grep -m1 '^server-port=' $dir/server.properties 2>/dev/null | cut -d= -f2)
    if test -z "$srvport"
        return
    end
    for f in ~/mc/bot/.bots/*
        if not test -f "$f"
            continue
        end
        set -l bport (string split ' ' <$f)[1]
        if test "$bport" = "$srvport"
            mc-better-bot kick (basename $f)
        end
    end
end
