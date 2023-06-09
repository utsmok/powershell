
# Main functionality here
# grabs all URLs from all files current dir and all subdirs
# looks through .log, .txt, .md, .R, .py, .ipynb files

$pattern = 'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
$types = ('*.log', '*.txt', '*.md', '*.R', '*.py', '*.ipynb')
$files = Get-ChildItem -Path $pwd -Include $types -Recurse 
 
$hits = $files `
  | Select-String -Pattern $pattern -AllMatches `

$names =  $hits | Group-Object path `
| Select-Object name

$URLLIST = $hits `
  | ForEach-Object { $_.Matches } `
  | ForEach-Object { $_.Value } `
  | ForEach-Object {$_.TrimEnd(".")} `
  | ForEach-Object {$_.TrimEnd(":")} `
  | ForEach-Object {$_.Trim(")")} `
  | Sort-Object `
  | Get-Unique 

$numberofURLS = $URLLIST.count
$namesstring = $names | out-string

Write-Host "Search done.
Found $numberofURLS URLs in the following files:" $namesstring -ForegroundColor Green

#######
# Storing the results in a CSV
#######

$filename = 'FileSearchResults.csv'
$file = Join-Path -Path $pwd -ChildPath $filename
$loop = $true

#UI for creating the csv
while ($loop) {
  Write-Host "Creating $file to store all found urls with corresponding filenames."
  if (Test-Path -Path $file -PathType Leaf) {
    $prompt = Read-Host -Prompt "Cannot create $file because a file with that name already exists. Overwrite?
    ([y]es/[c]hange name of output/[n]o, stop script)"
    Switch($prompt) {
      y {
      "Overwriting file $file." ;
      Remove-Item $file -Force ;
      $loop = $false
      }

      n {
        "Stopping script."; 
        exit
      }
      
      c {
      $filename = Read-Host -Prompt "What should the filename be?
      $pwd\[input]"
      $file = $file = Join-Path -Path $pwd -ChildPath $filename
      $test = Read-Host -Prompt "The filename will be $file. Is this correct? 
      [y]es/[n]o, exit script"
      Switch($test){
        y {
          $loop = $false
        }

        n {
          "Stopping script."; 
          exit
        }
      }
      }

      Default {
        "Answer was not recognized. Stopping script."
        exit
      }
    }
  } 
  else {
      try {
        New-Item $file -Force
        Write-Host "Found results will be added to $file."
        $loop = $false
      }
      catch {
        throw $_.Exception.Message  
      }
    }
}

$results = @()
Foreach( $URL in $URLLIST){
  $data = $files | Select-String $URL | Select-Object line,path
  $result = [ordered] @{ URL = $URL; file = $data.path }
  $result | Export-Csv $file -Append -NoTypeInformation -Force
  $results += ($result) 
}

#######
# Storing network check results in a CSV
#######

$filename = 'URLScanResult.csv'
$httpfile = Join-Path -Path $pwd -ChildPath $filename
$loop = $true

#UI for creating the csv for storing the scan results
while ($loop) {
  Write-Host "Creating $httpfile to store scan results."
  if (Test-Path -Path $httpfile -PathType Leaf) {
    $prompt = Read-Host -Prompt "Cannot create $httpfile because a file with that name already exists. Overwrite?
    ([y]es/[c]hange name of output/[n]o, stop script)"
    Switch($prompt) {
      y {
      "Overwriting file $httpfile." ;
      Remove-Item $httpfile -Force ;
      $loop = $false
      }

      n {
        "Stopping script."; 
        exit
      }
      
      c {
      $filename = Read-Host -Prompt "What should the filename be?
      $pwd\[input]"
      $httpfile = $httpfile = Join-Path -Path $pwd -ChildPath $filename
      $test = Read-Host -Prompt "The filename will be $httpfile. Is this correct? 
      [y]es/[n]o, exit script"
      Switch($test){
        y {
          $loop = $false
        }

        n {
          "Stopping script."; 
          exit
        }
      }
      }

      Default {
        "Answer was not recognized. Stopping script."
        exit
      }
    }
  } 
  else {
      try {
        New-Item $httpfile -Force
        Write-Host "Results will be added to $httpfile."
        $loop = $false
      }
      catch {
        throw $_.Exception.Message  
      }
    }
}

##########
# Get a HTTP response for every found URL
# Store results in CSV
##########

Foreach($Uri in $URLList) {
  try{
      
    #For proxy systems
      [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
      [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

      #Web request
      $req = Invoke-WebRequest -Uri $Uri
      $res = $req.StatusCode
  }catch {
      #Err handling
      $res = $_.Exception.Response.StatusCode.value__
  }
  $req = $null


  if($res -eq 200) {
    $opts = @{ForegroundColor="Green"}
  } else {
    $opts = @{ForegroundColor="Red"}
  }

  #Print results in console
  Write-Host @opts "$res - $Uri" 
  #append data to CSV
  New-Object PSObject -Property @{ URL = $Uri; Response = $res } `
  | Export-Csv $httpfile -Append -NoTypeInformation -Force
  
  #Disposing response if available
  if($req){
      $req.Dispose()
  }
}

Write-Host "All results were saved in $file." -ForegroundColor Green

#Write-Host "HTTP scan results for each URL were saved in $httpfile." -ForegroundColor Green




