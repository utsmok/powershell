###########################
#
#  Powershell script to make nice columns from messy author data.
#  Usage: Run this script in a dir that contains the csv, xlsx, or xls that contains the data.
#  The script will show you all found files of that type and ask which one you want to open.
#  Then it will show you all found columns, indicate which one(s) contain the data and which one contain the ID.
#  It will then split the author data into columns, and exports it as a csv.
#
#  By S. Mok, 6-6-2023, s.mok@utwente.nl
###########################

Install-Module -Name ImportExcel

#########
# Get list of files and column names and let the user pick
#########

$files = Get-ChildItem -Path $pwd -Recurse -Include $('*.csv', '*.xlsx', '*.xls')

#$numberedFiles = $files | ForEach-Object -Begin { $index = 0 } -Process { $index++; "[$index] $($_.Name)" }

Write-Host -BackgroundColor Black -ForegroundColor White "Found the following files:"

$i=0
foreach($file in $files) {
  $i++
  Write-Host -BackgroundColor Black -ForegroundColor Green "[$i] " -NoNewline
  Write-Host -BackgroundColor Black -ForegroundColor White "$($file.Name)"
}
$selectedFileIndex = $(Write-Host "Enter the number of the file you want to open: " -ForegroundColor Blue -BackgroundColor Black  -NoNewline ; Read-Host)
$workingfile = $files[$selectedFileIndex - 1]

Write-Host -ForegroundColor Green -BackgroundColor Black "Opening file:" $workingfile
$fileType = $workingfile.Extension

if($fileType -eq '.csv') {
    $file = Import-Csv -Path $workingfile.FullName
    $columns = $file | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
} else {
    $file = Import-Excel $workingfile.FullName 
    $columns = $file | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

}

Write-Host -BackgroundColor Black -ForegroundColor White  "Found the following columns:"
$i=0
$numcolumns = @()
foreach($column in $columns) {
  $i++
  Write-Host -BackgroundColor Black -ForegroundColor Green "[$i] " -NoNewline
  Write-Host -BackgroundColor Black -ForegroundColor White "$column"
  $numcolumn=[ordered] @{ column = $column; number = $i }
  $numcolumns += $numcolumn
}
$suggestedcolumn = ($numcolumns | Where-Object {$_.column -like "*Author*"}).number[0]
$selectedColumnIndex =  $(Write-Host -ForegroundColor Blue -BackgroundColor Black "Enter the number of the column that contains the messy data. Suggested:" -NoNewline ; Write-Host -BackgroundColor Black -ForegroundColor Green "[$suggestedcolumn] :" -NoNewLine; Read-Host)
$data = $file | Select-Object $columns[$selectedColumnIndex-1]
$columnnamedata = $data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
Write-Host -ForegroundColor Green -BackgroundColor Black "Selected column for authors:" $columnnamedata

$suggestedcolumn = ($numcolumns | Where-Object {$_.column -like "*#*"}).number[0]
$selectedColumnIndex =  $(Write-Host -ForegroundColor Blue -BackgroundColor Black "Enter the number of the column that contains an unique ID per paper. Suggested:" -NoNewline ; Write-Host -BackgroundColor Black -ForegroundColor Green "[$suggestedcolumn] :" -NoNewLine; Read-Host)
$IDdata = $file | Select-Object $columns[$selectedColumnIndex-1]
$IDdataname = $IDdata | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
Write-Host -ForegroundColor Green -BackgroundColor Black "Selected column for ID:" $IDdataname

#####################
# Loop through the data in the column and extract the info
#####################


$includeNonUT=$true
$results = @()
$i=0

foreach($entry in $data) {

    $number = $IDdata[$i].$IDdataname
    $mess = $entry.$columnnamedata
    $i += 1
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
                $university = "Yes"
                $institute = ""

                $department = $author   | Select-String -Pattern '[\sa-zA-Z\u00C0-\u024F\u1E00-\u1EFF\&\+\-]+(?=Organisational\sunit:\sDepartment)' `
                                        | ForEach-Object { $_.Matches } `
                                        | ForEach-Object { $_.Value } `
                                        | ForEach-Object {$_.Trim(" ")}
                
                if($department -like "*Taken over*") {
                    $department = $department -replace "Taken over by ", ""
                }
                #missing entries with: - Former organisational unit???

                $institute = $author    | Select-String -Pattern '[\sa-zA-Z\u00C0-\u024F\u1E00-\u1EFF\&\+\-]+(?=Organisational\sunit:\sInstitute)'  `
                                        | ForEach-Object { $_.Matches } `
                                        | ForEach-Object { $_.Value } `
                                        | ForEach-Object {$_.Trim(" ")}
                <#$university = $author   | Select-String -Pattern '[\sa-zA-Z\u00C0-\u024F\u1E00-\u1EFF\&\+\-]+(?=Organisational\sunit:\sUniversity)'  `
                                        | ForEach-Object { $_.Matches } `
                                        | ForEach-Object { $_.Value } `
                                        | ForEach-Object {$_.Trim(" ")}#>
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
                    UT = $university;
                    OriginalAuthor = $author
                                        }

                $results += $result
                $yesno = ""
 

            } elseif($includeNonUT) {
                $name = ""
                $department = ""
                $university = "No"
                $institute = ""
                $name = $author.Trim(" ", ",")
                if($name){ 
                    $result += [ordered] @{ ID = $number
                        CorrespondingAuthor = $yesno;
                        Name = $name; 
                        Department = $department; 
                        Institute = $institute; 
                        UT = $university;
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
                $university = "No"
                $institute = ""
                $yesno = ""
            }


        }
    }
}

Write-Host -ForegroundColor Green -BackgroundColor Black "Cleanup done. Extracted $($results.Count) authors from $($IDData.Count) entries."

#######
# Store the results in a CSV
#######

$filename = 'authorresults.csv'
$output = Join-Path -Path $pwd -ChildPath $filename

try {
  New-Item $output -Force
  Write-Host -ForegroundColor Green -BackgroundColor Black "Saving data to $output."
}

catch {
  throw $_.Exception.Message  
}

#add data to csv
foreach($result in $results){
  $result | Export-Csv $output -Append -NoTypeInformation -Force
} 




<#
  Code for user-prompted output

  #select output filepath
  $loop = $true
  while ($loop) {
    Write-Host -ForegroundColor Blue -BackgroundColor Black "Creating $output to store data."
    if (Test-Path -Path $output -PathType Leaf) {
      $prompt =  $(Write-Host -ForegroundColor Red -BackgroundColor Black "Cannot create $output because a file with that name already exists. Overwrite?";
      Write-Host -Foregroundcolor Blue -BackgroundColor Black "([y]es/[c]hange name of output/[n]o, stop script): "  -NoNewline ; Read-Host)
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
        $filename =  $(Write-Host -ForegroundColor Blue -BackgroundColor Black -Prompt "What should the filename be? 
        $pwd\[input]"  -NoNewline ; Read-Host)
        $output = $output = Join-Path -Path $pwd -ChildPath $filename
        $test =  $(Write-Host -ForegroundColor Blue -BackgroundColor Black -Prompt "The filename will be $output. Is this correct? 
        [y]es/[n]o, exit script"  -NoNewline ; Read-Host)
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
          Write-Host -ForegroundColor Green -BackgroundColor Black "Found results will be added to $output."
          $loop = $false
        }
        catch {
          throw $_.Exception.Message  
        }
      }
  }

#>




#######
# Analysis & add to original sheet
#######

$resultsperID =Import-Csv $output | Group-Object ID
$addedcolumn=@()

foreach($result in $resultsperID){
  $UT="Unknown"
  $id=$result.Group.ID | Get-Unique
  $utauthors=($result.Group | Where-Object UT -eq "Yes").count
  $nonutauthors=($result.Group | Where-Object UT -eq "No").count
  $totalauthors=$result.Group.count
  $totalyes = ($result.Group | Where-Object {$_.CorrespondingAuthor -eq "Yes"} | Select-Object CorrespondingAuthor).count
  $utyes = ($result.Group | Where-Object {$_.UT -eq "Yes"} | Where-Object {$_.CorrespondingAuthor -eq "Yes"} | Select-Object CorrespondingAuthor).count
  $nonutyes = ($result.Group | Where-Object {$_.UT -eq "No"} | Where-Object {$_.CorrespondingAuthor -eq "Yes"} | Select-Object CorrespondingAuthor).Count
  
  #uncomment this for analysis in the prompt
  <#$outputtable = @"
                -------------------------------
                    Analysis for paper $id
                -------------------------------
                        Authors         
                    UT  $utauthors      
                Non-UT  $nonutauthors   
                 Total  $totalauthors 
                 
                        Corresponding Authors
                    UT  $utyes
                Non-UT  $nonutyes
                 Total  $totalyes
"@

$outputtable #>

  if($totalyes -eq 1){
    if($utyes -eq 1){
      $UT="Yes"
    } elseif($nonutyes -ge 1) {
      $UT="No"
    } else{
      $UT="Unknown"
    }
  } elseif($totalyes -eq 0){
    $UT="None"	
  } else {
    if($totalyes -eq $utyes){
      $UT="Yes"
    } elseif($totalyes -eq $nonutyes){
      $UT="No"
    } else {
      $UT="Unknown"
    }

  }
  $corrauthdata = [ordered] @{ ID = $id; UTCorrespondingAuthor = $UT ; NrTotalCorresponding = $totalyes ; NrUTCorresponding = $utyes; NrNonUTCorresponding = $nonutyes}
  $addedcolumn += $corrauthdata
}

#code to prompt user if they want to save over the original excel
<#$addtosheet =  $(Write-Host -ForegroundColor Blue -BackgroundColor Black "Do you want to update the original sheet with the processed data? ([y]es/[n]o):" -NoNewline ; Read-Host) 	
if($addtosheet -eq "y") {
  $addtosheet=$true
} elseif ($addtosheet -eq "n") {
  $addtosheet=$false
  Write-Host -ForegroundColor Red -BackgroundColor Black "Not updating the original sheet. Stopping the script."
} else {
  $addtosheet=$false
  Write-Host -ForegroundColor Green -BackgroundColor Black "Answer was not recognized, defaulting to no and stopping the script."
}#>

$utyestotal = ($addedcolumn | Where-Object {$_.UTCorrespondingAuthor -eq "Yes"}).count
$utnototal = ($addedcolumn | Where-Object {$_.UTCorrespondingAuthor -eq "No"}).count
$utunktotal = ($addedcolumn | Where-Object {$_.UTCorrespondingAuthor -eq "Unknown"}).count

Write-Host -ForegroundColor Green -BackgroundColor Black "Analysis done:
    Total number of papers: $($IDData.Count) 
    Total number of UT papers: $utyestotal 
    Total number of non-UT papers: $utnototal 
    Total number of unknown papers: $utunktotal "

$addtosheet=$true
if($addtosheet){
  if($fileType -eq '.csv') {
      $file 
  } else {  #excel!
      foreach($row in $file){
        $id=$row.$IDdataname
        $row | Add-Member -Force -MemberType NoteProperty -Name UTCorrespondingAuthor -Value ($addedcolumn | Where-Object ID -eq $row.$IDdataname).UTCorrespondingAuthor
        
       #Display underlying data for error checking
        <# if($row.UTCorrespondingAuthor -eq "Unknown" -or $row.UTCorrespondingAuthor -eq "No") {
          Write-Host "No corresponding UT author found for item $id. Details:"
          Write-Host "Name                           UT?  CorrespondingAuthor?"
          $errorresult = ($resultsperID.Group | Where-Object ID -eq $row.$IDdataname | Select-Object Name, UT, CorrespondingAuthor)
          $errorresult
       }#>

      }
      Write-Host -ForegroundColor Green -BackgroundColor Black "Adding final data to $workingfile in worksheet Automation results."
      $file | Export-Excel $workingfile -Show -WorksheetName "Automation results"
  }
}