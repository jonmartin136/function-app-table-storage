param ([int] $Requests = 1, [int] $ThrottleLimit = 50, [string] $Url = "https://fas-eunn-poc-demo.azurewebsites.net/api/app")
1..$Requests | ForEach-Object -Parallel { Write-Host ('{0:d5}: {1}' -F $_, (& curl -s -X POST $using:Url)) } -ThrottleLimit $ThrottleLimit
