function _mc_list_servers --description "List directories that contain a server jar"
    for d in ~/mc/*/
        set -l jars $d*.jar
        if test -f "$jars[1]"
            basename "$d"
        end
    end
end
