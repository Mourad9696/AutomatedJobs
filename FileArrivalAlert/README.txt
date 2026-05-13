##################################################################
#### Settelment Files alert automated script (V1) ###
##################################################################

1- Naming conventions are based on the .NET naming conventions.
	 1A - For constants, UPPER_CASE is used
	 1B - For global variables, PascalCase is used
	 1C - For functions, Verb-Noun case is used

2- This script performs a check every X minutes for any files that are sent from Visa's side.
3- Logs are dumped to this path C:\VCXMonitoringJobs\FilesArrivalAlert\FilesArrivalLogs in case of success or faliure.