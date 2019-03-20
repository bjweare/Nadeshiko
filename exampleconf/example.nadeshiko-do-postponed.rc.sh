# nadeshiko-do-postponed.rc.sh v2.0


 # Limit the number of CPU cores, on which the encoding process may run.
#  The value is a string, as for taskset --cpu-list: “0”, “1,3”, “1-2,5”.
#
#taskset_cpulist='1-2'


 # Process priority. −20…19, the lower the higher, default is 0.
#  The value is a number, as for nice -n: “-5”, “-20”, “19”.
#  Negative values require superuser privilegies.
#
#niceness_level='-20'


 # Defines verbosity level for the backend.
#  This option controls, whether notifications would be sent after each
#    encoded video, or there will be just one “All jobs processed.”
#  Possible values:
#    “none” – Nadeshiko (the backend) will not send any desktop notifications.
#             (But Nadeshiko-do-postponed will still inform you, when all jobs
#              would be done.)
#    “error” – Send a desktop notification, only when a video wasn’t encoded
#              successfully.
#    “all” – The normal behaviour, each time a video is encoded, a message
#            is sent. This allows to watch it as soon as it is ready.
#  Default: all
#
nadeshiko_desktop_notifications='all'