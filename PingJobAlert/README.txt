##################################################################
#### FTPS command channel automated alerts script (V1) ###
##################################################################

1- Naming conventions are based on the .NET naming conventions.
	 1A - For constants, UPPER_CASE is used
	 1B - For global variables, PascalCase is used
	 1C - For functions, Verb-Noun case is used

2- This script performs a ICMP check if Visa's FTPS command channel is up or not by pinging on it every 5 minutes
3- Logs are dumped to this path C:\VCXMonitoringJobs\DestinationPingJob\PingLogs in case of success or faliure.