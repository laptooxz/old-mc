function mc
    set cmd $argv[1]
    set srv $argv[2]

    if test -z "$cmd"
        echo "Usage: mc <command> [server]"
        echo ""
        echo "Commands:"
        echo "  start    Start server in tmux"
        echo "  stop     Stop server gracefully"
        echo "  restart  Restart server gracefully"
        echo "  console  Attach to server console"
        echo "  logs     View logs (tail -f)"
        echo "  backup   Create backup"
        echo "  restore  Restore from backup"
        echo "  status   Check if server is running"
        echo "  check    Check server files"
        echo "  rmworld  Delete world folder"
        echo "  list     List all servers"
        echo "  whitelist  Manage whitelist (list|add <player>|remove <player>)"
        echo "  bot      Manage offline bots (list|join [username] [-b]|kick <username>)"
        return 1
    end

    if test -n "$srv"
        if test "$cmd" != create
            set dir ~/mc/$srv
            set session mc-$srv

            if not test -d $dir
                echo "Server '$srv' does not exist."
                echo "Available servers:"
                _mc_list_servers
                return 1
            end
        end
    end

    switch $cmd
        case list
            echo "Available servers:"
            _mc_list_servers

        case check
            if test -z "$srv"
                echo "Usage: mc check <server>"
                return 1
            end
            set jarfile (ls $dir/*.jar 2>/dev/null | head -1)
            if test -n "$jarfile"
                echo "$srv: VALID ($jarfile)"
            else
                echo "$srv: INVALID (no .jar file)"
            end

        case watch
            if sudo rc-service mc-watcher status 2>&1 | grep -q "started"
                echo "mc-watcher is running. It auto-detects active servers."
            else
                echo "mc-watcher is not running. Start with: sudo rc-service mc-watcher start"
            end

        case start
            if test -z "$srv"
                echo "Usage: mc start <server>"
                return 1
            end
            set jarfile (ls $dir/*.jar 2>/dev/null | head -1)
            if test -z "$jarfile"
                echo "Error: No .jar file found in $srv"
                return 1
            end
            set jarbase (basename $jarfile)

            if tmux has-session -t $session 2>/dev/null
                echo "Server $srv is already running (tmux session found)."
                return 1
            end
            if pgrep -f "$jarbase" >/dev/null 2>&1
                set pid (pgrep -f "$jarbase" | head -1)
                echo "Server $srv process already running (PID $pid). Killing stale process..."
                kill $pid 2>/dev/null; sleep 1
                kill -9 $pid 2>/dev/null; sleep 1
            end

            cd $dir
            set java_cmd (cat $dir/.java_version 2>/dev/null || echo "java")
            set runcmd (echo $mcargs | sed "s|paper.jar|$jarbase|; s|^java |$java_cmd |")
            tmux new-session -d -s $session "$runcmd"
            echo "Minecraft $srv started in tmux session $session"
            _mc_notify "$srv" "Server started" "start"

        case stop
            if test -z "$srv"
                echo "Usage: mc stop <server>"
                return 1
            end
            set jarfile (ls $dir/*.jar 2>/dev/null | head -1)
            if test -z "$jarfile"
                echo "No .jar file found for $srv"
                return 1
            end
            set jarname (basename $jarfile)

            if not tmux has-session -t $session 2>/dev/null
                echo "Server $srv is not running (no tmux session)."
                return 1
            end

            echo "Stopping $srv..."
            _mc_kick_bots $dir
            tmux send-keys -t "$session" Enter
            tmux send-keys -t "$session" "tellraw @a {\"text\":\"Server Shutting Down...\",\"color\":\"red\",\"bold\":true}" Enter 2>/dev/null
            sleep 3
            tmux send-keys -t "$session" "stop" Enter

            set timeout 30
            set elapsed 0
            while tmux has-session -t $session 2>/dev/null
                if test $elapsed -ge $timeout
                    echo "Server did not stop after $timeout seconds."
                    read -P "Force kill? [y/N] " -l confirm
                    if string match -q "y" "$confirm"
                        set pids (pgrep -f "tmux new-session -d -s $session" 2>/dev/null; pgrep -f "\-jar $jarname" 2>/dev/null)
                        if test -n "$pids"
                            kill -9 $pids 2>/dev/null
                        end
                    else
                        echo "Not force killing. The server may still be shutting down."
                    end
                    break
                end
                sleep 2
                set elapsed (math $elapsed + 2)
            end
            echo "Server stopped."

            if tmux has-session -t $session 2>/dev/null
                tmux kill-session -t $session
            end
            _mc_notify "$srv" "Server stopped" "stop"

        case restart
            if test -z "$srv"
                echo "Usage: mc restart <server>"
                return 1
            end
            set jarfile (ls $dir/*.jar 2>/dev/null | head -1)
            if test -z "$jarfile"
                echo "No .jar file found for $srv"
                return 1
            end
            set jarname (basename $jarfile)

            if not tmux has-session -t $session 2>/dev/null
                echo "Server $srv is not running."
                return 1
            end

            echo "Restarting $srv..."
            _mc_kick_bots $dir
            tmux send-keys -t "$session" Enter
            tmux send-keys -t "$session" "tellraw @a {\"text\":\"Server Restarting...\",\"color\":\"gold\",\"bold\":true}" Enter 2>/dev/null
            sleep 3
            tmux send-keys -t "$session" "stop" Enter

            set timeout 30
            set elapsed 0
            while tmux has-session -t $session 2>/dev/null
                if test $elapsed -ge $timeout
                    echo "Server did not stop after $timeout seconds."
                    read -P "Force kill? [y/N] " -l confirm
                    if string match -q "y" "$confirm"
                        set pids (pgrep -f "tmux new-session -d -s $session" 2>/dev/null; pgrep -f "\-jar $jarname" 2>/dev/null)
                        if test -n "$pids"
                            kill -9 $pids 2>/dev/null
                        end
                    else
                        echo "Not force killing. The server may still be shutting down."
                    end
                    break
                end
                sleep 2
                set elapsed (math $elapsed + 2)
            end

            if tmux has-session -t $session 2>/dev/null
                tmux kill-session -t $session
            end

            echo "Starting $srv..."
            cd $dir
            set java_cmd (cat $dir/.java_version 2>/dev/null || echo "java")
            set runcmd (echo $mcargs | sed "s|paper.jar|$jarname|; s|^java |$java_cmd |")
            tmux new-session -d -s $session "$runcmd"
            echo "Minecraft $srv restarted in tmux session $session"
            _mc_notify "$srv" "Server restarted" "start"
            tmux attach-session -t $session

        case console
            if test -z "$srv"
                echo "Usage: mc console <server>"
                return 1
            end
            if not tmux has-session -t $session 2>/dev/null
                echo "Server $srv is not running."
                return 1
            end
            tmux attach-session -t $session

        case logs
            if test -z "$srv"
                echo "Usage: mc logs <server>"
                return 1
            end
            if not test -f $dir/logs/latest.log
                echo "No logs found for $srv"
                return 1
            end
            tail -f $dir/logs/latest.log

        case backup
            if test -z "$srv"
                echo "Usage: mc backup <server>"
                return 1
            end
            if not test -d $dir/world
                echo "No world folder found in $srv"
                return 1
            end
            set dest /mnt/HDD/mc
            if not test -d $dest
                mkdir -p $dest
            end
            set ts (date +%Y-%m-%d_%H%M)
            set start (date +%s)
            set tar_dirs world
            if test -d $dir/world_nether
                set tar_dirs $tar_dirs world_nether
            end
            if test -d $dir/world_the_end
                set tar_dirs $tar_dirs world_the_end
            end
            tar -czvf $dest/$srv-$ts.tar.gz -C $dir $tar_dirs
            set end (date +%s)
            set duration (math $end - $start)
            set dur_str (_mc_format_duration $duration)
            echo "Backup created: $dest/$srv-$ts.tar.gz ($dur_str)"
            _mc_notify "$srv" "Backup finished in $dur_str" "window-attention"

        case rmworld
            if test -z "$srv"
                echo "Usage: mc rmworld <server>"
                return 1
            end
            if not test -d $dir/world
                echo "No world folder found in $srv"
                return 1
            end
            echo "World folder: $dir/world"
            read -P "Backup world before deleting? [y/N] " confirm
            if test "$confirm" = "y" -o "$confirm" = "Y"
                set dest /mnt/HDD/mc
                if not test -d $dest
                    mkdir -p $dest
                end
                set ts (date +%Y-%m-%d_%H%M)
                set bluemap_maps
                for w in world world_nether world_the_end
                    if test -d $dir/bluemap/web/maps/$w
                        set bluemap_maps $bluemap_maps bluemap/web/maps/$w
                    end
                end
                tar -czf $dest/$srv-world-$ts.tar.gz -C $dir world world_nether world_the_end $bluemap_maps
                echo "Backup created: $dest/$srv-world-$ts.tar.gz"
            end
            read -P "WARNING: This will DELETE world data for $srv. Continue? [y/N] " confirm
            if test "$confirm" = "y" -o "$confirm" = "Y"
                rm -rf $dir/world $dir/world_nether $dir/world_the_end

                for w in world world_nether world_the_end
                    rm -rf $dir/bluemap/web/maps/$w
                    rm -f $dir/plugins/BlueMap/maps/$w.conf
                    rm -f $dir/plugins/Chunky/tasks/$w.properties
                end

                echo "World deleted for $srv"
                _mc_notify "$srv" "World deleted" "message-new-instant"
            else
                echo "Cancelled."
            end

        case restore
            if test -z "$srv"
                echo "Usage: mc restore <server> (backup-file)"
                return 1
            end
            set backupfile $argv[3]
            if test -z "$backupfile"
                echo "Available backups:"
                ls -lt /mnt/HDD/mc/*$srv*.tar.gz 2>/dev/null | head -5
                echo ""
                echo "Usage: mc restore <server> (backup-file)"
                return 1
            end
            if not test -f "$backupfile"
                echo "Backup file not found: $backupfile"
                return 1
            end

            set jarfile (ls $dir/*.jar 2>/dev/null | head -1)
            if test -n "$jarfile"
                set jarname (basename $jarfile)
                if pgrep -f "$jarname" >/dev/null 2>&1
                    echo "Stopping $srv..."
                    mc stop $srv
                end
            end

            set start (date +%s)
            tar -xzf $backupfile -C $dir
            set end (date +%s)
            set duration (math $end - $start)
            set dur_str (_mc_format_duration $duration)
            echo "Restored $srv from $backupfile ($dur_str)"
            _mc_notify "$srv" "Restore finished in $dur_str" "window-attention"

        case status
            if test -z "$srv"
                echo "Usage: mc status <server>"
                return 1
            end
            set jarfile (ls $dir/*.jar 2>/dev/null | head -1)
            if test -z "$jarfile"
                echo "$srv: INVALID (no .jar file)"
                return 1
            end
            set jarname (basename $jarfile)
            if pgrep -f "$jarname" >/dev/null 2>&1
                echo "$srv: RUNNING"
            else if tmux has-session -t $session 2>/dev/null
                echo "$srv: STOPPED (stale tmux session)"
            else
                echo "$srv: STOPPED"
            end

        case whitelist
            if test -z "$srv"
                echo "Usage: mc whitelist <server> (list|add <player>|remove <player>)"
                return 1
            end
            set action $argv[3]
            if test -z "$action"
                echo "Usage: mc whitelist <server> (list|add <player>|remove <player>)"
                return 1
            end
            switch $action
                case list
                    if not test -f $dir/whitelist.json
                        echo "No whitelist.json found for $srv"
                        return 1
                    end
                    set entries (python3 -c "
import json, sys
with open('$dir/whitelist.json') as f:
    data = json.load(f)
if not data:
    print('(empty)')
else:
    for e in data:
        print('  {name:>16s}  ({uuid})'.format(**e))
")
                    echo "Whitelist for $srv:"
                    echo "$entries"
                case add
                    set player $argv[4]
                    if test -z "$player"
                        echo "Usage: mc whitelist $srv add <player>"
                        return 1
                    end
                    if not tmux has-session -t $session 2>/dev/null
                        echo "Server $srv is not running."
                        return 1
                    end
                    echo "Adding $player to $srv whitelist..."
                    tmux send-keys -t "$session" "whitelist add $player" Enter
                    sleep 1
                    grep -h "whitelist" $dir/logs/latest.log 2>/dev/null | tail -1 | string replace -r '.*\]: (.+)' '$1'
                case remove
                    set player $argv[4]
                    if test -z "$player"
                        echo "Usage: mc whitelist $srv remove <player>"
                        return 1
                    end
                    if not tmux has-session -t $session 2>/dev/null
                        echo "Server $srv is not running."
                        return 1
                    end
                    echo "Removing $player from $srv whitelist..."
                    tmux send-keys -t "$session" "whitelist remove $player" Enter
                    sleep 1
                    grep -h "whitelist" $dir/logs/latest.log 2>/dev/null | tail -1 | string replace -r '.*\]: (.+)' '$1'
                case '*'
                    echo "Unknown whitelist action: $action"
                    echo "Usage: mc whitelist <server> (list|add <player>|remove <player>)"
            end

        case bot
            if test -z "$srv"
                mc-better-bot list
                return
            end
            set sub $argv[3]
            switch $sub
                case '' list ls
                    mc-better-bot list
                case join
                    set srvport (grep -m1 '^server-port=' $dir/server.properties 2>/dev/null | cut -d= -f2)
                    if test -z "$srvport"
                        set srvport 25565
                    end
                    mc-better-bot join -p $srvport $argv[4..-1]
                case kick stop
                    if test -z "$argv[4]"
                        echo "Usage: mc bot $srv kick <username>"
                        return 1
                    end
                    mc-better-bot kick $argv[4]
                case '*'
                    echo "Usage: mc bot <server> [list | join [username] [-b] | kick <username>]"
                    return 1
            end

        case '*'
            echo "Unknown command: $cmd"
    end
end
