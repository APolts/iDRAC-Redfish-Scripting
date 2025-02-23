<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 7.0
Copyright (c) 2019, Dell, Inc.

This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>




<#
.Synopsis
   iDRAC cmdlet using Redfish API to either get virtual media information, attach or eject virtual media located on supported network share. 
.DESCRIPTION
   iDRAC cmdlet using Redfish API to either get virtual media information, attach or eject virtual media located on supported network share. Supported network shares are NFS, CIFS, HTTP and HTTPS.
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
   - get_virtual_media_info: Pass in "y" to get current virtual media information.
   - x_auth_token: Pass in iDRAC X-Auth token session to execute cmdlet instead of username / password (recommended)
   - virtual_media_action: Type of action you want to perform. Pass in "1" if you want perform Insert, pass in "2" if you want to perform Eject.
   - virtual_media_device: Type of virtual media device you want to use. Pass in "1" for CD or "2" for removable disk. 
   - uri_path: For insert virtual media, pass in the URI path of the remote image. Note: If attaching removable disk, only supported file type is .img'
   - network_share_username: Pass in the share username if using CIFS or secured HTTPS
   - network_share_password: Pass in the share username password if using CIFS or secured HTTPS
.EXAMPLE
   Invoke-InsertEjectVirtualMediaREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -get_virtual_media_info y
   This example will return virtual media information for virtual CD and virtual removable disk.
.EXAMPLE
   Invoke-InsertEjectVirtualMediaREDFISH -idrac_ip 192.168.0.120 -get_virtual_media_info y
   This example will first prompt for iDRAC username/password using Get-Credential, then return virtual media information for virtual CD and virtual removable disk.
.EXAMPLE
   Invoke-InsertEjectVirtualMediaREDFISH -idrac_ip 192.168.0.120 -get_virtual_media_info y -x_auth_token 7bd9bb9a8727ec366a9cef5bc83b2708
   This example will return virtual media information for virtual CD and virtual removable disk using iDRAC X-Auth token session. 
.EXAMPLE
   Invoke-InsertEjectVirtualMediaREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -virtual_media_action 1 -virtual_media_device 1 -uri_path http://192.168.0.130/http_share/esxi.iso
   This example will attach ISO on HTTP share as a virtual CD.
.EXAMPLE
   Invoke-InsertEjectVirtualMediaREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -virtual_media_action 1 -virtual_media_device 1 -uri_path //192.168.0.130/cifs_share/esxi.iso -network_share_usrname admin -network_share_password Password123 
   This example will attach ISO on CIFS share as a virtual CD.
.EXAMPLE
   Invoke-InsertEjectVirtualMediaREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -virtual_media_action 2 -virtual_media_device 2
   This example will detach virtual removable disk.
#>

function Invoke-InsertEjectVirtualMediaREDFISH {


param(
    [Parameter(Mandatory=$True)]
    [string]$idrac_ip,
    [Parameter(Mandatory=$False)]
    [string]$idrac_username,
    [Parameter(Mandatory=$False)]
    [string]$idrac_password,
    [Parameter(Mandatory=$False)]
    [string]$x_auth_token,
    [Parameter(Mandatory=$False)]
    [string]$get_virtual_media_info,
    [Parameter(Mandatory=$False)]
    [string]$virtual_media_action,
    [Parameter(Mandatory=$False)]
    [string]$virtual_media_device,
    [Parameter(Mandatory=$False)]
    [string]$uri_path,
    [Parameter(Mandatory=$False)]
    [string]$network_share_username,
    [Parameter(Mandatory=$False)]
    [string]$network_share_password
    )
 

# Function to ignore SSL certs

function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}


# Setting up iDRAC credentials for functions  

function setup_idrac_creds
{

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12

if ($x_auth_token)
{
$global:x_auth_token = $x_auth_token
}
elseif ($idrac_username -and $idrac_password)
{
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$global:credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
}
else
{
$get_creds = Get-Credential
$global:credential = New-Object System.Management.Automation.PSCredential($get_creds.UserName, $get_creds.Password)
}
}

# function to get Powershell version

function get_powershell_version 
{
$get_host_info = Get-Host
$major_number = $get_host_info.Version.Major
$global:get_powershell_version = $major_number
}

# Function to test if iDRAC version supports this cmdlet

function test_iDRAC_version 

{
$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD"
   if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}
}


# Function to GET virtual media information 

function get_virtual_media_info

{
$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia?`$expand=*(`$levels=1)"
    if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}
$result = $result.Content | ConvertFrom-Json
Write-Host "`n- Virtual Media Information -`n"
$result.Members
return


}

# Function to perform virtual media action insert

function virtual_media_insert

{
if ($virtual_media_device -eq 1)
{
$u1 = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD/Actions/VirtualMedia.InsertMedia"
$get_uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD"
}
elseif ($virtual_media_device -eq 2)
{
$u1 = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/RemovableDisk/Actions/VirtualMedia.InsertMedia"
$get_uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/RemovableDisk"
}
else
{
Write-Host "`n- FAIL, invalid value passed in for parameter 'virtual_media_device'"
return
}

if ($network_share_username -and $network_share_password)
{
$JsonBody = @{'Image'=$uri_path;'Inserted'=$true;'WriteProtected'=$true; 'UserName' = $network_share_username; 'Password' = $network_share_password} 
}
else
{
$JsonBody = @{'Image'=$uri_path;'Inserted'=$true;'WriteProtected'=$true} 
}

$JsonBody = $JsonBody | ConvertTo-Json -Compress
   if ($x_auth_token)
{
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $u1 -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -UseBasicParsing -Uri $u1 -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    } 
}


else
{
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $u1 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -UseBasicParsing -Uri $u1 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    } 
}

if ($result1.StatusCode -eq 204)
{
[String]::Format("`n- PASS, POST command passed for Virtual Media Insert, status code {0} returned", $result1.StatusCode)


}   
    if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $get_uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $get_uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $get_uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $get_uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}
    $result1.Content | ConvertFrom-Json
    

    Write-Host
    $final_results = $result.Content | ConvertFrom-Json
if ($final_results.Inserted -eq $true)
{
Write-Host "- PASS, GET command passed and verified virtual media device is attached(insert)`n"
}
else
{
Write-Host "- FAIL, verification failed to verify virtual media device is attached"
return
}
    
return
}


# Function to perform virtual media action eject

function virtual_media_eject

{
if ($virtual_media_device -eq 1)
{
$u1 = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD/Actions/VirtualMedia.EjectMedia"
$get_uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD"
}
elseif ($virtual_media_device -eq 2)
{
$u1 = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/RemovableDisk/Actions/VirtualMedia.EjectMedia"
$get_uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/RemovableDisk"
}
else
{
Write-Host "`n- FAIL, invalid value passed in for parameter 'virtual_media_device'"
return
}
$JsonBody = @{} | ConvertTo-Json -Compress
    if ($x_auth_token)
{
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $u1 -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -UseBasicParsing -Uri $u1 -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    } 
}


else
{
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $u1 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -UseBasicParsing -Uri $u1 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    } 
}
if ($result1.StatusCode -eq 204)
{
[String]::Format("`n- PASS, POST command passed for Virtual Media Eject, status code {0} returned", $result1.StatusCode)
} 



  if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $get_uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $get_uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $get_uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $get_uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

    Start-Sleep 5
    $final_results = $result.Content | ConvertFrom-Json
if ($final_results.Inserted -eq $false)
{
Write-Host "`n- PASS, GET command passed and verified virtual media device is detached(eject)`n"
}
else
{
Write-Host "`n- FAIL, verification failed to verify virtual media device is detached"
return
}
    
return
}


# Run code

get_powershell_version
setup_idrac_creds
test_iDRAC_version

if ($get_virtual_media_info -ne "")
{
get_virtual_media_info
}
elseif ($virtual_media_action -eq 1)
{
virtual_media_insert
}
elseif ($virtual_media_action -eq 2)
{
virtual_media_eject
}
else
{
Write-Host "- FAIL, either invalid parameter value passed in or missing required parameter"
return
}

}


