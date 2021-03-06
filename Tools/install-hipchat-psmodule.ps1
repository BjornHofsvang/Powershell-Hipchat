<#
 Creation Date:    10/2/2016 10:30 PM EST

 Author:           Marcus Bastian (BastianM3@GitHub)

 Script Name:      install-hipchat-psmodule.ps1

 Synopsis:         Downloads and installs a PowerShell module for HipChat. The HipChat PS module
                   allows you to post a variety of messages to your HipChat rooms. Such module
                   was written by Mark Wragg. 

                   You can find his GitHub project here:
                   https://github.com/markwragg/Powershell-Hipchat.git                  
#>
[CmdletBinding()]
Param(
    $desiredVerbosePref = 'Continue',
    $VerbosePreference = $desiredVerbosePref,
    $PathToGitExe = "$env:systemdrive\git\cmd\git.exe",
    $PSHipChatModuleRepoURL = "https://github.com/markwragg/Powershell-Hipchat.git" ,
    $CurUsrModulesPath = "$env:UserProfile\Documents\WindowsPowerShell\Modules"
)

Function New-CurUserPsModulesPath
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([Boolean])]
	Param($ModulesPath)

    If(-not $(test-path $ModulesPath))
    {
        write-verbose "PowerShell modules directory does not exist under UserProfile. Attempting to create."
        new-item $ModulesPath -itemType Directory -ea SilentlyContinue;
        if(test-path $ModulesPath)
        {
            write-verbose "Successfully created Modules directory."
            return $true
        } else {
            write-verbose "Failed to create Modules directory under this user!"
            return $false
        }
    } else {
        return $true
    }
}

Function Export-ZipArchive ($PathToZip,$destination)
{
    # Extracts the provided zip archive into the destination provided..

    # Possible output:
    #
    #    All files extracted = $true
    #    Failed to extract   = $false
    #    No items in archive = $null

    $shellApplication = new-object -com shell.application
    $zipPackage = $shellApplication.NameSpace($PathToZip)

    write-verbose "$PathToZip"

    If(-not(test-path $destination))
    {
        new-item -itemType Directory $destination;
    }

    $countBefore = (Get-ChildItem $destinationFolder -ea SilentlyContinue | measure-object).Count;
    write-verbose "$countBefore folders in destination directory before extracting zip. "

    $destinationFolder = $shellApplication.NameSpace($destination)

    write-verbose "Extracting to $DestinationFolder";
    write-verbose $ZipPackage

    If($zipPackage)
    {
        # extract files
        $destinationFolder.CopyHere($zipPackage.Items(), 20)

        $countAfter = (Get-ChildItem $destinationFolder -ea SilentlyContinue | measure-object).Count;
        write-verbose "$countBefore folders in destination directory after extracting zip. "

        if($countAfter -eq $countBefore)
        {
            write-error "Could not find extracted files in desired destination after attempting to extract."
            return $false;
        }
        else
        {
            return $true;
        }
    }
    {
        # no items in archive
        return $null;
    }

}

Function Install-Git
{
    $git_installer_url = "https://github.com/git-for-windows/git/releases/download/v2.10.0.windows.1/MinGit-2.10.0-32-bit.zip"
    $git_zip_save_as = "$env:windir\temp\GitInstaller_archive.zip"
    $git_installation_directory = "$env:systemdrive\git"

    invoke-webrequest -uri $git_installer_url -outfile $git_zip_save_as | out-null

    if(-not (test-path $git_zip_save_as))
    {
        write-error "Failed to download Git installer zip. Cannot proceed.";
        return $false;
    } else {
        write-verbose "Successfully downloaded portable Git archive. Proceeding to extract archive."
    }


    # Extract archive to desired Git directory

    $extractedOk = Export-ZipArchive -pathtoZip $git_zip_save_as -destination $git_installation_directory;

    if($extractedOk -ne $true)
    {
        write-error "Failed to extract Git installer archive." 
        return $false
    } else {
        write-verbose "Successfully extracted Git installer archive."
    }

    $expected_git_exe_path = "$git_installation_directory\cmd\git.exe"
    if(test-path $expected_git_exe_path)
    {
        # a success!
        return $true
    } else {
        write-error "Git installation has failed. Unable to locate git.exe here: `t $expected_git_exe_path."
        return $false;
    }

}

Function Stop-Script
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param($ExitCode)

    $error | Format-List -property * | out-file $PsErrors_LogFile
    exit $exitCode;
}

Function Copy-HipChatPsModule($repoURL, $moduleSaveLocation, $pathToGitExe)
{

    # Change current working directory to PS module directory
    set-location $moduleSaveLocation;

    # Fire off git clone command 
    start-process $pathToGitExe -argumentList "clone", $repoURL -Wait

    # verify that direct exists
    if(Get-ChildItem "Powershell-Hipchat")
    {
        return $true
    } else {
        return $false
    }
}

Function Add-UserPSModulePath($newPsModulePath)
{
    #Save the current value in the $p variable.
    $p = [Environment]::GetEnvironmentVariable("PSModulePath")

    #Add the new path to the $p variable. Begin with a semi-colon separator.
    $p += ";$newPsModulePath\"

    #Add the paths in $p to the PSModulePath value.
    [Environment]::SetEnvironmentVariable("PSModulePath",$p)

}


##############################
#   SCRIPT BEGINS HERE      
# Create PsModules path under current user profile if it does not exist

Write-Verbose $PSHipChatModuleRepoURL
Write-Verbose $CurUsrModulesPath

$pathExists = New-CurUserPsModulesPath -ModulesPath $CurUsrModulesPath

if($pathExists -ne $true) { 
    Write-Verbose "$pathExists does not exist"
    Return
}

# Append the newly created PSModule path to the PSModulePath environment variable 
Add-UserPSModulePath $CurUsrModulesPath;

# Download / install MinGit for Windows~
$gitInstalledOk = Install-Git

if($gitInstalledOk -ne $true)
{
    write-error "Git did not install properly. Unable to continue with module installation."
    return;
}

# Download HipChat PowerShell module from Git Repo

$paramObj = @{
    repoURL = $PSHipChatModuleRepoURL
    moduleSaveLocation = $CurUsrModulesPath
    pathToGitExe = $PathToGitExe
}

$clonedOk = Copy-HipChatPsModule @paramObj

if($clonedOk -eq $true)
{
    write-verbose "Cloned HipChat module successfully! Renaming cloned directory to match underlying psm1 file."
} else {
    write-error "Failed to clone HipChat repository into the PSModules directory."
}

rename-item "$CurUsrModulesPath\Powershell-Hipchat" "hipchat"

$HipChatModulesAvailable = (get-module -ListAvailable hipchat).count;

if($HipChatModulesAvailable -ge 1)
{
    write-output "Successfully installed HipChat PowerShell module!";
} else {
    write-output "Failed to install HipChat PowerShell module."
}
