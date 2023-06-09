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
Write-Host "Found $numberofURLS URLs in the following files:" $namesstring

$results = New-Object System.Collections.ArrayList

Foreach( $URL in $URLLIST){
  $data = Get-ChildItem -r | Select-String $URL | Select-Object line,path
  $result = New-Object PSObject -Property @{ URL = $data.line; file = $data.path }
  $results.Add($result) 
}

Write-Host $result