##########################################
#### PSQL backup automated script (V1) ###
##########################################

1- Naming conventions are based on the .NET naming conventions.
	 1A - For constants, UPPER_CASE is used
	 1B - For global variables, PascalCase is used
	 1C - For functions, Verb-Noun case is used

2- This script performs a clear-text backup and compresses it using 7-Zip, also secured with a password.
3- Logs are dumped to this path C:\VCXMonitoringJobs\PsqlJobLog in case of success or faliure.