# Load WinSCP .NET assembly
Add-Type -Path (Join-Path $PSScriptRoot "WinSCPnet.dll")
 
# Session.FileTransferred event handler
 
function FileTransferred
{
    param($e)
 
    if ($e.Error -eq $Null)
    {
        Write-Host ("Upload of {0} succeeded" -f $e.FileName)
    }
    else
    {
        Write-Host ("Upload of {0} failed: {1}" -f $e.FileName, $e.Error)
    }
 
    if ($e.Chmod -ne $Null)
    {
        if ($e.Chmod.Error -eq $Null)
        {
            Write-Host ("Permisions of {0} set to {1}" -f $e.Chmod.FileName, $e.Chmod.FilePermissions)
        }
        else
        {
            Write-Host ("Setting permissions of {0} failed: {1}" -f $e.Chmod.FileName, $e.Chmod.Error)
        }
 
    }
    else
    {
        Write-Host ("Permissions of {0} kept with their defaults" -f $e.Destination)
    }
 
    if ($e.Touch -ne $Null)
    {
        if ($e.Touch.Error -eq $Null)
        {
            Write-Host ("Timestamp of {0} set to {1}" -f $e.Touch.FileName, $e.Touch.LastWriteTime)
        }
        else
        {
            Write-Host ("Setting timestamp of {0} failed: {1}" -f $e.Touch.FileName, $e.Touch.Error)
        }
 
    }
    else
    {
        # This should never happen during "local to remote" synchronization
        Write-Host ("Timestamp of {0} kept with its default (current time)" -f $e.Destination)
    }
}

function Sync-SecureFiles {
	[CmdletBinding(SupportsShouldProcess=$false,DefaultParameterSetName="Password")]
	Param(
		[Parameter(Mandatory=$true,Position=0,HelpMessage="Local path to a directory")]
		[String]$LocalPath,
        [Parameter(Mandatory=$true,Position=1,HelpMessage="Remote path to a directory")]
		[String]$RemotePath,
        [Parameter(Mandatory=$false,HelpMessage="Direction to sync TO, either Remote, Local or Both, defaults to Remote.")]
		[WinSCP.SynchronizationMode]$SynchronizationMode = [WinSCP.SynchronizationMode]::Remote,
        [Parameter(Mandatory=$true,HelpMessage="Host name or IP")]
		[String]$HostName,
        [Parameter(Mandatory=$true,HelpMessage="Username")]
		[String]$UserName,
        [Parameter(Mandatory=$true,ParameterSetName="Password",HelpMessage="Password for host.")]
		[String]$Password,
        [Parameter(Mandatory=$false,HelpMessage="Defaults to SCP")]
        [WinSCP.Protocol]$Protocol = [WinSCP.Protocol]::Scp,
        [Parameter(Mandatory=$false,HelpMessage="Ignores host fingerprint and accepts.")]
        [Switch]$GiveUpSecurityAndAcceptAnySshHostKey,
        [Parameter(Mandatory=$false,HelpMessage="Specify a host fingerprint.")]
        [String]$SshHostKeyFingerprint,
        [Parameter(Mandatory=$false,HelpMessage="Deletes obsolete files, cannot be used with SynchronizationMode both")]
        [String]$removeFiles,
        [Parameter(Mandatory=$false,HelpMessage="Hides results output")]
        [Switch]$Silent

	)
	Begin {
        #Put begining stuff here
	}
	Process {

        try
        {
            $sessionOptions = New-Object WinSCP.SessionOptions
            $sessionOptions.Protocol = $Protocol
            $sessionOptions.HostName = $HostName
            $sessionOptions.UserName = $UserName
            $sessionOptions.Password = $Password
            $sessionOptions.GiveUpSecurityAndAcceptAnySshHostKey = $GiveUpSecurityAndAcceptAnySshHostKey
            if ($SshHostKeyFingerprint) {
                $sessionOptions.SshHostKeyFingerprint = $SshHostKeyFingerprint
            }
 
            $session = New-Object WinSCP.Session
            try
            {
                # Will continuously report progress of synchronization
                if (!$Silent) {
                    $session.add_FileTransferred( { FileTransferred($_) } )
                }
 
                # Connect
                $session.Open($sessionOptions)
        
                #$session.ListDirectory("/oracle/fileattachments/prod/")

                $transferOptions = New-Object WinSCP.TransferOptions
                $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

                # Synchronize files
                $synchronizationResult = $session.SynchronizeDirectories($SynchronizationMode, $LocalPath, $RemotePath, $False, $false, [WinSCP.SynchronizationCriteria]::Time , $transferOptions)
 
                # Throw on any error
                $synchronizationResult.Check()
            }
            finally
            {
                # Disconnect, clean up
                $session.Dispose()
            }
 
            #exit 0
        }
        catch [Exception]
        {
            Write-Host $_.Exception.Message
            #exit 1
        }

	}
	End {
        #Put end here
	}
}

Export-ModuleMember -Function "Sync-SecureFiles"
