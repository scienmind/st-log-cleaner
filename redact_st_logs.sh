#!/bin/bash

# Version: 2.3
# 
# Changelog: 
#   v.2.3 - Fix compatibility issue with macOS
#   v.2.2 - Reformat info printouts
#   v.2.1 - Protect from paths with spaces breaking the scipt
#   v.2.0 - Complete rewrite to use config.xml as data source, remove IP info usnig patterns     

function terminate {
    echo "$1"
    echo "               Usage:   $0  <syncthing_config_file.xml> <syncthing_log_file.log>"
    exit
}

if (( $# != 2 )); then
    terminate "   ! Error ! : Wrong input parameters!"
elif [[ "$1" != *.xml || "$2" != *.log ]]; then
    terminate "   ! Error ! : Wrong input parameters!"
elif [[ ! -f "$1" || ! -f "$2" ]]; then 
    terminate "   ! Error ! : Input file is not available"
fi

config_file="$1"
log_file="$2"

echo "   Starting cleanup of $log_file..."
echo -n "   Loading configuration data from $config_file..."
config_data=`cat "$config_file"`
# load the log and convert to LF line endings
log_data=`cat "$log_file" | sed $'s/\r$//'`

devices=`echo "$config_data" | grep "device id=" | grep name | sort | cut -d"\"" -f2,4 | tr "\"" " " | uniq`
device_ids=`echo "$devices" | cut -d" " -f1`
device_ids_short=`echo "$device_ids" | cut -c1-7`
device_ids_shortest=`echo "$device_ids_short" | cut -c1-5`
device_names=`echo "$devices" | cut -d' ' -f2-`

folders=`echo "$config_data" | grep "folder id=" | sort | cut -d"\"" -f2,4,6 | uniq`
folder_ids=`echo "$folders" | cut -d"\"" -f1`
folder_labels=`echo "$folders" | cut -d"\"" -f2`
# tr produces a warning about unescaped backslashed during conversion; warning suppressed:
folder_paths=`echo "$folders" | cut -d"\"" -f3 | tr -s '\\'  '\n' 2> /dev/null | awk '{print length,$0}' | sort -n -r | awk ' {$1="";print $0}' | cut -f2- -d' ' | uniq | awk 'length($0)>2'`

addresses_v4=`echo "$log_data" | grep -o -E '([0-9]{1,3}\.){3}([0-9]{1,3})' | sort | uniq`
# IPv6 regex by: https://stackoverflow.com/a/17871737 :
addresses_v6=`echo "$log_data" | grep -o -E '(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))' | sort | uniq`
ports=`echo "$log_data" | grep -o -E '((\.[0-9]{1,3})|(\]))(\:)([0-9]{1,5})' | cut -d":" -f2 | sort -n | uniq`

echo "   Done"

function replace_strings {
    log_data="$1"
    originals_list="$2"
    replacement_string="$3"
    cnt=0
    while read original_string; do
        # replace only non-empty strings while preserving count:
        if [[ $original_string == *[a-zA-Z0-9]* ]]; then
            log_data="${log_data//$original_string/${replacement_string}_$cnt}"
        fi
        let cnt++
    done <<< "$originals_list"
}

echo -n "   Redacting device info..."
replace_strings "$log_data" "$device_ids" IDID-IDID-IDID-IDID
replace_strings "$log_data" "$device_ids_short" IDIDID
replace_strings "$log_data" "$device_ids_shortest" IDID
replace_strings "$log_data" "$device_names" DEVICE
echo "   Done"
echo -n "   Redacting folder info..."
replace_strings "$log_data" "$folder_ids" FOLDER_ID
replace_strings "$log_data" "$folder_labels" FOLDER_LABEL
replace_strings "$log_data" "$folder_paths" F_PATH 
echo "   Done"
echo -n "   Redacting IP info..."
replace_strings "$log_data" "$addresses_v4" IPv4
replace_strings "$log_data" "$addresses_v6" IPv6
replace_strings "$log_data" "$ports" PORT
echo "   Done"

puller_warning=`echo "$log_data" | tr '\r' '\n' | grep Puller | wc -l`
if (( $puller_warning )); then
    echo "   ! Warning ! : \"Puller\" messages detected: the log may contain unredacted filenames/paths"
    echo "                 Notice: Deleting those messages will remove potentially useful debugging information"
    read -p "                 Remove \"Puller\" log messages? [Y/n] " answer   
    if [[ "$answer" == Y || "$answer" == y ]]; then
        log_data=`echo "$log_data" | grep -v Puller`
        echo "                 \"Puller\" log messages removed"
    fi
fi

output_file="${log_file%.*}"_redacted.log
# write the log to file and convert back to CR-LF line endings
echo "$log_data" | sed $'s/$/\r/' > "$output_file"

echo "   Finished! Redacted log stored in $output_file"
