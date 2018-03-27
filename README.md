# st-log-cleaner
#### Shell script to remove personal info from log files produced by [Syncthing](https://github.com/syncthing/syncthing)

---

#### Usage: 
Run: `redact_st_logs.sh /path/to/syncthing_config_file.xml /path/to/syncthing_log_file.log`

#### Operation principle:

The script utilizes syncthing’s config file to find the data to be anonymized. Config file is scanned for: device IDs, device names, folder IDs, folder labels, folder paths. The, all data occurences in the log file are replaced with consistently-enumerated generic placeholders. In addition, IP addresses and port numbers patterns are detected and replaced as well.

Sample log before/after redaction: [diff](https://www.diffchecker.com/N0Iyj69U)

---

Known issues:

- Sometimes syncthing reports issues related to specific filenames or sub-directories, the script can't really detect those entries automatically. 

    Current workaround: I've noticed that most of such data comes form Puller module, so the script checks for theis module and will prompt the user to remove it’s messages entirely. It may not be always a good idea, since in some occasions this data may be essential to debugging.

