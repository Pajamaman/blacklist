#/bin/bash

log="log.txt"
config="config.txt"
cache_dir="cache"
local_date="hdate.txt"
remote_date="http://securemecca.com/Downloads/hdate.txt"
local_hosts="hosts.txt"
remote_hosts="http://securemecca.com/Downloads/hosts.txt"
blacklist="blacklist.hosts"

cd "${BASH_SOURCE%/*}" || exit

echo -e "\nLog started $(date)" >> "$log"

add_hosts=()
remove_hosts=()

if [ -f "$config" ]; then
    while IFS='= ' read key value; do
        case "$key" in
            blacklist_add_host)
                add_hosts=("${add_hosts[@]}" "$value") ;;
            blacklist_remove_host)
                remove_hosts=("${remove_hosts[@]}" "$value") ;;
            blacklist_upload_dest)
                upload_dest="$value" ;;
        esac
    done < "$config"
fi

if [ ! -d "$cache_dir" ]; then
    mkdir "$cache_dir"
fi

echo "Downloading $remote_date..." | tee -a "$log"

if ! wget -qO "$local_date" "$remote_date"; then
    echo "Error: $?" | tee -a "$log"
    exit 1
fi

echo "Done" | tee -a "$log"

if [ ! -f "$cache_dir/$local_hosts" ]; then
    echo "First run" | tee -a "$log"
    download=true
elif [ "$cache_dir/$local_date" -ot "$local_date" ]; then
    echo "Hosts file is out of date" | tee -a "$log"
    download=true
else
    echo "Hosts file is up to date" | tee -a "$log"
    download=false
fi

mv "$local_date" "$cache_dir"

if [ "$download" = true ]; then
    echo "Downloading $remote_hosts..." | tee -a "$log"

    if ! wget -qO "$cache_dir/$local_hosts" "$remote_hosts"; then
        echo "Error: $?" | tee -a "$log"
        exit 2
    fi

    echo "Done" | tee -a "$log"
fi

echo "Building $blacklist..." | tee -a "$log"

sed "s/$//" "$cache_dir/$local_hosts" > "$blacklist"

for add_host in "${add_hosts[@]}"; do
    echo "127.0.0.1	$add_host" >> "$blacklist"
done

for remove_host in "${remove_hosts[@]}"; do
    sed -i "s/^127.0.0.1	$remove_host/#127.0.0.1	$remove_host/" "$blacklist"
done

echo "Done" | tee -a "$log"

if [ -n "$upload_dest" ]; then
    if ! echo "$upload_dest" | grep -Eq ".+@.+:.+"; then
        echo "Upload destination is not valid" | tee -a "$log"
        exit 3
    fi

    echo "Uploading to $upload_dest..." | tee -a "$log"

    cat "$blacklist" | ssh "${upload_dest%:*}" "cat > ${upload_dest#*:}; /etc/init.d/dnsmasq restart"

    echo "Done" | tee -a "$log"
fi

