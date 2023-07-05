###########################
#
#  Powershell script to make nice columns from messy author data.
#  Usage: Run this script in a dir that contains the csv, xlsx, or xls that contains the data.
#  The script will show you all found files of that type and ask which one you want to open.
#  Then it will show you all found columns, indicate which one(s) contain the data.
#  It will then split the data into columns, show a preview, and asks to confirm before either updating the original file or exporting as a new file.
Install-Module -Name ImportExcel


# get all possible files
$files = Get-ChildItem -Path $pwd -Recurse -Include $('*.csv', '*.xlsx', '*.xls')

# display list of found files, numbered, ask user which one to open

$numberedFiles = $files | ForEach-Object -Begin { $index = 0 } -Process { $index++; "[$index] $($_.Name)" }

Write-Host "Found files:" $numberedFiles
$selectedFileIndex = Read-Host "Enter the number of the file you want to open"
$workingfile = $files[$selectedFileIndex - 1]

Write-Host "Opening file:" $workingfile
$fileType = $workingfile.Extension

if($fileType -eq '.csv') {
    $file = Import-Csv -Path $workingfile.FullName
    $columns = $file | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
} else {
    $file = Import-Excel $workingfile.FullName 
    $columns = $file | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

}

$numberedcolumns = $columns | ForEach-Object -Begin { $index = 0 } -Process { $index++; "[$index] $_" }
Write-Host "Found columns:" $numberedcolumns
$selectedColumnIndex = Read-Host "Enter the number of the column that contains the garbled data"
$data = $file | Select-Object $columns[$selectedColumnIndex-1]
$columnnamedata = $data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

$selectedColumnIndex = Read-Host "Now enter the number of the column that contains the ID of the paper"
$IDdata = $file | Select-Object $columns[$selectedColumnIndex-1]
$IDdataname = $IDdata | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name




$includeNonUT=$true
$results = @()
$i=0

foreach($entry in $data) {
    $i += 1
    $number = $IDdata[$i].$IDdataname
    $mess = $entry.$columnnamedata
    
    #init arrays
    $authors = @()
    $result = @()
    
    $yesno = ""
    #Split the entry for each author by using the Yes/No pattern
    $authors += @([Regex]::Split($mess, '(Yes):|(No):'))
    
 
    #for each author grab the yes or no, then fix up author info and merge to get an entry
    foreach ($author in $authors) {
        $result = @()
        

        if(($author -eq "Yes") -Or ($author -eq "No")) {
            $yesno = $author
            
        } else {
            if($author -like "*:*") {
                
                $name = ""
                $department = ""
                $university = ""
                $institute = ""

                $department = $author   | Select-String -Pattern '[\sa-zA-Z\u00C0-\u024F\u1E00-\u1EFF\&\+\-]+(?=Organisational\sunit:\sDepartment)' `
                                        | ForEach-Object { $_.Matches } `
                                        | ForEach-Object { $_.Value } `
                                        | ForEach-Object {$_.Trim(" ")}
                if($department -like "*Taken over*") {
                    $department = $department -replace "Taken over by ", ""
                }
                $institute = $author    | Select-String -Pattern '[\sa-zA-Z\u00C0-\u024F\u1E00-\u1EFF\&\+\-]+(?=Organisational\sunit:\sInstitute)'  `
                                        | ForEach-Object { $_.Matches } `
                                        | ForEach-Object { $_.Value } `
                                        | ForEach-Object {$_.Trim(" ")}
                $university = $author   | Select-String -Pattern '[\sa-zA-Z\u00C0-\u024F\u1E00-\u1EFF\&\+\-]+(?=Organisational\sunit:\sUniversity)'  `
                                        | ForEach-Object { $_.Matches } `
                                        | ForEach-Object { $_.Value } `
                                        | ForEach-Object {$_.Trim(" ")}
                $name = $author         | Select-String -Pattern '[.\sa-zA-Z\u00C0-\u024F\u1E00-\u1EFF\&\+\-]+(?=:)' `
                                        | Select-Object -First 1  `
                                        | ForEach-Object { $_.Matches } `
                                        | ForEach-Object { $_.Value } `
                                        | ForEach-Object {$_.Trim(" ")}
            
                $result = [ordered] @{ ID = $number
                    CorrespondingAuthor = $yesno;
                    Name = $name; 
                    Department = $department; 
                    Institute = $institute; 
                    University = $university;
                    OriginalAuthor = $author
                                        }

                $results += $result
                $yesno = ""
 

            } elseif($includeNonUT) {
                $name = ""
                $department = ""
                $university = "Probably Non-UT"
                $institute = ""
                $name = $author.Trim(" ", ",")
                if($name){ 
                    $result += [ordered] @{ ID = $number
                        CorrespondingAuthor = $yesno;
                        Name = $name; 
                        Department = $department; 
                        Institute = $institute; 
                        University = $university;
                        OriginalAuthor = $author
                                            }
                    

                    $results += $result
                }
                $yesno = ""
                $university = ""
                $yesno = ""

            } elseif(-Not $includeNonUT){
                $name = ""
                $department = ""
                $university = ""
                $institute = ""
                $yesno = ""
            }


        }
    }
}

#loop through and remove duplicates??

#######
# 
# Store the results in a CSV
#######

$filename = 'columnresults.csv'
$output = Join-Path -Path $pwd -ChildPath $filename
$loop = $true

while ($loop) {
  Write-Host "Creating $output to store all found urls with corresponding filenames."
  if (Test-Path -Path $output -PathType Leaf) {
    $prompt = Read-Host -Prompt "Cannot create $output because a file with that name already exists. Overwrite?
    ([y]es/[c]hange name of output/[n]o, stop script)"
    Switch($prompt) {
      y {
      "Overwriting file $output." ;
      Remove-Item $output -Force ;
      $loop = $false
      }

      n {
        "Stopping script."; 
        exit
      }
      
      c {
      $filename = Read-Host -Prompt "What should the filename be?
      $pwd\[input]"
      $output = $output = Join-Path -Path $pwd -ChildPath $filename
      $test = Read-Host -Prompt "The filename will be $output. Is this correct? 
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
        New-Item $output -Force
        Write-Host "Found results will be added to $output."
        $loop = $false
      }
      catch {
        throw $_.Exception.Message  
      }
    }
}

foreach($result in $results){
    $result | Export-Csv $output -Append -NoTypeInformation -Force
} 