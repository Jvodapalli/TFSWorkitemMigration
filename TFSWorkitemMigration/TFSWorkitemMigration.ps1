param(
$TFSOnPrURL, #source url
$TFSonprCollection, #source project name
$VSTSURL, #destination url
$VSTSProjectname ,#destination project name
$DownloadLocalPath,#local or shared path where you want to download attachments from source url
$path , #attjson.txt file which is in github need to download and mention the path location
$WIqueryFolder, #name fo the folder where query is saved like My queries, shared
$wiqueryname, #name of the query created for migration
$Excelpath,#full path of excel file locationex: "C:\Users\jvodapalli\Desktop\Wimi.csv"
$personalAccessToken  #personalization token for vsts migration
)
function get-listofchildWI($id)
{
    write-host "getting list of child Workitems"
    $tfsUri = "$TFSOnPrURL/$TFSonprCollection/_apis/wit/workItems/$($id)"+'?$expand=relations&api-version=2.0'
    $linkresponse = Invoke-RestMethod -Method get -Uri $tfsUri -Credential $cred
    $linkvalues = $linkresponse.relations
    return $linkvalues
}

function get-tfsWiresponse($TFSWI)
{
    Write-Host "getting $TFSWI workitem response"
    $tfsUri = "$TFSOnPrURL/$TFSonprCollection/_apis/wit/workItems/$($TFSWI)"+'?$expand=relations&api-version=2.0'
    $tfsresponse = Invoke-RestMethod -Method get -Uri $tfsUri -Credential $cred
    return $tfsresponse
}

function create-WIonvsts($witype)
{
    $uri = "$($VSTSURL)/$($VSTSProjectname)/_apis/wit/workItems/$"+"Task?api-version=2.0"
    if($witype -eq "task"){$state = "To Do" }
    else { $state = "New"}
    $WIJson = ConvertTo-Json @(@{
                                     op="add"
                                     path= "/fields/System.Title"
                                     value= "created $WIid EPIC WI using powershell api" }
                                    @{
                                     op="add"
                                     path= "/fields/system.WorkItemType"
                                     value= "$witype" }
                                @{
                                     op="add"
                                     path= "/fields/system.state"
                                     value= "$state" }
                                      @{
                                     op="add"
                                     path= "/fields/system.Reason"
                                     value= "New $witype" }
                                     )
    write-host "creating new Wi in destination "                                  
    $WIcreateresponse = Invoke-RestMethod -Method PATCH -Uri $uri -Body $WIJson -headers @{Authorization = 'Basic' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)")) }  -ContentType "application/json-patch+json"
    $VSTSWI = $WIcreateresponse.id
    return $VSTSWI
}

function create-BugWIonvsts($witype)
{
$uri = "$($VSTSURL)/$($VSTSProjectname)/_apis/wit/workItems/$"+"Task?api-version=2.0"
$WIJson = ConvertTo-Json @(@{
                                     op="add"
                                     path= "/fields/System.Title"
                                     value= "created $WIid EPIC WI using powershell api" }
                                    @{
                                     op="add"
                                     path= "/fields/system.WorkItemType"
                                     value= "$witype" }
                                @{
                                     op="add"
                                     path= "/fields/system.state"
                                     value= "New" }
                                      @{
                                     op="add"
                                     path= "/fields/system.Reason"
                                     value= "New $witype" }
                                      @{
                                     op="add"
                                     path= "/fields/customscrum.Bugsource"
                                     value= "Deployment to Production" }
                                      @{
                                     op="add"
                                     path= "/fields/customscrum.Bugtype"
                                     value= "Boundary Condition" }
                                     )
write-host "creating new Bug Wi im vsts $VSTSURL"                                  
$WIcreateresponse = Invoke-RestMethod -Method PATCH -Uri $uri -Body $WIJson -headers @{Authorization = 'Basic' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)")) }  -ContentType "application/json-patch+json"
$VSTSWI = $WIcreateresponse.id
return $VSTSWI
}

function update-requiredtags($VSTSWI,$Witype)
{
  Write-Host "started updating the fields for WI"
  $uri ="$($VSTSURL)/_apis/wit/workItems/$($VSTSWI)"+'?$expand=relations&api-version=2.0'
  $tfsUri = "$($TFSOnPrURL)/$($TFSonprCollection)/_apis/wit/workitems/$($TFSWI)"+'?$expand=relations&api-version=2.0'
  write-host "WI url for migration is $tfsUri  "
  $response = Invoke-RestMethod -Method Get -Uri $tfsUri -Credential $cred
  if($Witype -ne "Bug" )
  {
    $Requiredtags = @("System.Description","system.tags","System.Title","system.state")
    $systemfields = ($response.fields | Get-Member ).Name -match "system"
  }
  if($Witype -eq "Bug")
  {$Requiredtags = @("System.Description","system.tags","System.Title","system.state","custom.source","custom.type")
    $systemfields = ($response.fields | Get-Member ).Name -match "system"
    $systemfields +=  ($response.fields | Get-Member ).Name -match "custom"
  }
  
  foreach($value in $Requiredtags)
  {
    if( $value -match ($systemfields -join "|"))
    {
      write-host "$value is ready to update " 
      $response = Invoke-RestMethod -Method Get -Uri $tfsUri -Credential $cred
      if($response.fields.$value)
      {
        write-host enterdloop
        $contentupdate  =$response.fields.$value 
        #to update the custom fields created in on premises 
               if($value -eq "custom.source")
                    { $value = "customscrum.Bugsource"
                    }
               if($value -eq "custom.type")
                     { $value = "customscrum.Bugtype"
                    }
          #below if loops are based on my senario if you have custom fields which are not created make sure to update the below if loops 
               if($contentupdate -eq "Deployment to QA or UAT")
                        {
                        $contentupdate = "Deployment (other)"
                        }
                        if($contentupdate -eq "Testing (QA)")
                        {
                        $contentupdate = "Testing (regression)"
                        }if($contentupdate -eq "Testing (Dev)")
                        {
                        $contentupdate = "Testing (development)"
                        }if($contentupdate -eq "Testing (UAT)")
                        {
                        $contentupdate = "Testing (User acceptance)"
                        }if($contentupdate -eq "Build Failed")
                        {
                        $contentupdate = "Build/deploy"
                        }
                        if($contentupdate -eq "Customer (Production)")
                        {
                        $contentupdate = "Customer/Production"
                        }
        $updateJson = convertto-json @(@{
                                     op="add"
                                     path= "/fields/$value"
                                     value= $contentupdate })
    Write-Host "updating $contentupdate to $updateJson  " 
    $updateResponse = Invoke-RestMethod -Method PATCH -Uri $uri -Body $updateJson -headers @{Authorization = 'Basic' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)")) }  -ContentType "application/json-patch+json"

       }
      }
     }
     return $updateResponse
     }

function check-wiexist($TFSWI)
{
    $WIArray = @{TFSWI=''
                 VSTSWI=''}
    $WIArray = Import-Csv -Path "$Excelpath" 
    $found= 0
    $k = $WIArray.TFSWI
        foreach($check in  $k )
        {
            if( $check -eq $TFSWI)
            { 
                write-host "work item already created for $check "
                $index = [array]::IndexOf($k,$check)
                $c= $WIArray.VSTSWI
                $VSTSWI = $c[$index]
                $found = 1         
            }
        }
        if( $found -eq 1)
            {
                write-host "migration is done $TFSWI -> $VSTSWI"
                return $VSTSWI
            }
            else 
            {
                Write-Host "Migrated item doesnt exist for $TFSWI started creating new WI in vsts"
                $Response = get-tfsWiresponse -TFSWI $TFSWI
                $Witype = $Response.fields.'System.WorkItemType'
                Write-Host "creating $Witype work item "
                if($Witype -ne "Bug")
                {
                $VSTSWI = create-WIonvsts -witype $Witype
                }
                else{
                $VSTSWI = create-BugWIonvsts -witype $Witype
                }
                Add-Content "$Excelpath" "$TFSWI,$VSTSWI"
                Write-Host "created wi$TFSWI --> $VSTSWI , started updating tags"
                $updatereqtagresponse = update-requiredtags -VSTSWI $VSTSWI -Witype $Witype
                if($Response.relations)
                    {
                    write-host "entered relation loop for checking attachments"
                    $attachmentInfo = $response.relations | where { $_.rel -eq 'attachedfile'}
                         if($attachmentInfo)
                         {
                             write-host "looking for file name"
                             $AttFilename = $attachmentInfo.attributes.name
                             write-host "name of the attachment  $AttFilename"
                             $Attachmenturl =$attachmentInfo.url
                             write-host "attachment Url  is $Attachmenturl"
                         }
                    }
                else
                    { 
                    $AttFilename = $null
                    }
#download an attachment
                if($AttFilename -ne $null )
                    {
                    foreach ($attinfo in $attachmentInfo)
                    {
                    $AttFilename = $attInfo.attributes.name
                             write-host "name of the attachment  $AttFilename"
                             $Attachmenturl =$attInfo.url
                             write-host "attachment Url  is $Attachmenturl"
                    write-host "started downloading file from on premises"
                    Invoke-RestMethod -Method Get $Attachmenturl -Credential $cred -OutFile "$DownloadLocalPath\$AttFilename" 
                    $attuploadUri = "$VSTSURL/_apis/wit/attachments?api-version=2.0&filename=$($AttFilename)"
                    $byte = [System.IO.File]::ReadAllBytes("$DownloadLocalPath\$AttFilename") 
                    write-host "upload an attachment"
                    $evolent = Invoke-RestMethod -Method post -Uri $attuploadUri  -headers @{Authorization = 'Basic' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)")) }  -ContentType application/octet-stream  -Body $byte
                    $attID = $evolent.id
                    write-host "guid for attachment $attID"
                    $attuploadURL = $evolent.url
                    write-host  "attchment url for $attuploadURL"
                    (Get-Content $path).replace('$URI',$attuploadURL)  | out-file $path
                    $attjson = Get-Content -Path "$path"
                    write-host $attjson
                    $uri2 ="$VSTSURL/_apis/wit/workItems/$($VSTSWI)?api-version=1.0"
                    Write-Host $uri2
                    (Get-Content $path).replace($attuploadURL, '$URI')  | out-file $path 
                    $c= Get-Content -Path "$path"
                    write-host "attaching atachment to WI vsts"
                    $attupdate = Invoke-RestMethod -Method Patch -Uri $Uri2  -headers @{Authorization = 'Basic' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)")) }  -ContentType application/json-patch+json -Body $attjson
                    Remove-Item -Path "$DownloadLocalPath\$AttFilename"
                   $AttFilename = $null
                    }

                    $contentupdate =$null
                   }
                    return $VSTSWI
                    
            }
}

function link-childWI($id, $VSTSWI)
{
$linkvalues =get-listofchildWI -id $id
$childTFSWI = @()
foreach($linkvalue in $linkvalues)
{
$linkvaluesrelTypes  = $linkvalue.rel
$linkvaluesUrl = $linkvalue.url
foreach($linkvaluesrelType in $linkvaluesrelTypes)
{ 

    if($linkvalue.rel -match "system")
    {
         Write-Host "entered loop"
         $TFSWI = $linkvaluesUrl.Split('/')[-1]
         $childTFSWI += $TFSWI
         $checkvalue = check-wiexist -TFSWI $TFSWI
         write-host "linking cWi to parent"
         $childVSTSWI = $checkvalue
         Write-Host "child work item is $childVSTSWI and parent wi is $id -> $VSTSWI "
         $linkurl = "$VSTSURL/_apis/wit/workItems/$childVSTSWI"
         $updateJson = convertto-json @(@{
                                     op="add"
                                     path= "/relations/-"
                                     value= @{
                                     url = "$linkurl" 
                                     rel = "$linkvaluesrelType"}
                                     attributes=@{comment = "making migration newlink"}
                                     })
         $linkupdateresponse = Invoke-RestMethod -Method PATCH -Uri "$VSTSURL/_apis/wit/workItems/$($VSTSWI)?api-version=2.0" -Body $updateJson -Headers @{Authorization = 'Basic' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)")) }  -ContentType "application/json-patch+json"
          write-host $linkupdateresponse 
          
    }}
}return $childTFSWI}

$found = $null
$cred = Get-Credential
$WIqueryUrl = "$TFSOnPrURL/$TFSonprCollection/DevOps/_apis/wit/queries/$WIqueryFolder/$wiqueryname/?api-version=2.0"
$WIqueryresponse = Invoke-RestMethod -Uri $WIqueryUrl -UseDefaultCredentials
$wiResponse = Invoke-RestMethod $WIqueryresponse._links.wiql.href -UseDefaultCredentials
$WIidqueryList  = $wiResponse.workItemRelations.target.id
$wiIDqueryurl = $wiResponse.workItemRelations.target.url
$WIidqueryList
$wiIDqueryurl
$VSTSWI = $null

foreach( $id in $WIidqueryList){
$checkvalue = check-wiexist -TFSWI $id
$VSTSWI = $checkvalue
$childTFSWI = @()
$childTFSWI = link-childWI -id $id -VSTSWI $VSTSWI
Write-Host "$childTFSWI are the feature"
If($childTFSWI -ne $null)
    {
        foreach($id in $childTFSWI)
        {
            write-host "entered loop for child  wi"
            $checkvalue = check-wiexist -TFSWI $id
            $VSTSWI = $checkvalue
            $innerchildTFSWI = link-childWI -id $id -VSTSWI $VSTSWI
            $innerchildTFSWI
        }
    }
If($innerchildTFSWI -ne $null)
    {
        foreach($id in $innerchildTFSWI)
        {
            write-host "entered loop for child  wi"
            $checkvalue = check-wiexist -TFSWI $id
            $VSTSWI = $checkvalue
            $innerloopchildTFSWI = link-childWI -id $id -VSTSWI $VSTSWI
            $innerloopchildTFSWI
        } 
    }
}




