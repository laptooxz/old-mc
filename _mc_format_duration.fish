function _mc_format_duration --description "Format seconds to human readable"
    set total $argv[1]
    if test $total -ge 60
        set m (math -s0 $total / 60)
        set s (math $total % 60)
        echo "$m"m "$s"s "($total"s")"
    else
        echo "$total"s
    end
end
