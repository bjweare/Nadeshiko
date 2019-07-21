#  nadeshiko-do-postponed.rc.sh
#
#  Main configuration file for nadeshiko-do-postponed.sh. Copied as an example
#  to user’s configuration directory from defconf/.
#
#  RC file uses bash syntax:
#    key=value
#  Quotes can be omitted, if the value is a string without spaces.
#  The equals sign should stick to both key and value – no spaces around “=”.
#
#  Nadeshiko wiki may answer a question before you ask it!
#  https://github.com/deterenkelt/Nadeshiko/wiki



 # Limits the number of CPU cores, on which the encoding process may run.
#  The value is a string, as for taskset --cpu-list: “0”, “1,3”, “1-2,5”.
#  Not used in the default configuration.
#
#taskset_cpulist='1-2'


 # OS process priority. −20…19, the lowest is the *higher* priority,
#    default OS priority is 0. Negative values require superuser privilegies.
#  Not used in the default configuration.
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