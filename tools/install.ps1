##
#
# Quick'n dirty helper to pickup a Kobo's USBMS mountpoint...
# Spoiler alert: I've never written anything in PowerShell before :D
# NOTE: Requires PowerShell 5+ (Expand-Archive. ALso, I only have a Win10 box to test this anyway ;p).
#
##

# Do a version check manually instead of relying on require, so we can keep the window open...
if ($PSVersionTable.PSVersion.Major -lt 5)
{
	Write-Warning -Message "This script requires PowerShell 5+ to run, but you're currently running PowerShell $(if (Test-Path Variable:\PSVersionTable) {$PSVersionTable.PSVersion} else {"1.0"})!"
	Read-Host -Prompt "* Can't do anything! Press Enter to exit"
	Exit 1
}

# Find out where the Kobo is mounted...
$KOBO_MOUNTPOINT=$NULL
$KOBO_MOUNTPOINT=Get-Disk | Where BusType -eq USB | Get-Partition | Get-Volume | Where FileSystemLabel -eq KOBOeReader

# Sanity check...
if ($NULL -eq $KOBO_MOUNTPOINT) {
	Write-Host("Couldn't find a Kobo eReader volume! Is one actually mounted?")
	Read-Host -Prompt "* Nothing to do! Press Enter to exit"
	Exit 1
}

# Now that we're sure we've got a Volume, get the actual mount point... (i.e., the Drive letter, without any suffix)
$KOBO_MOUNTPOINT=$KOBO_MOUNTPOINT.DriveLetter

$KOBO_DIR=$KOBO_MOUNTPOINT + ":\.kobo"
if (-NOT (Test-Path $KOBO_DIR)) {
	Write-Host("Can't find a .kobo directory, " + $KOBO_MOUNTPOINT + ": doesn't appear to point to a Kobo eReader... Is one actually mounted?")
	Read-Host -Prompt "* Nothing to do! Press Enter to exit"
	Exit 1
}

# Ask the user what they want to install...
# NOTE: Case is a joy on Windows (https://github.com/PowerShell/PowerShell/issues/7578),
#       so we simply prefix our package names to avoid accepting stock packages here...
$VALID_GLOBS=@("OCP-KOReader-v*.zip", "OCP-Plato-*.zip", "KFMon-v*.zip", "KFMon-Uninstaller*.zip")
$AVAILABLE_PKGS=@()
foreach ($pat in $VALID_GLOBS) {
	foreach ($file in Get-ChildItem -File -Name $pat) {
		if (Test-Path $file) {
			$AVAILABLE_PKGS+=$file
		}
	}
}

# Sanity check...
if ($AVAILABLE_PKGS.Length -eq 0) {
	Write-Host("No supported packages found in the current directory (" + $pwd +")!")
	Read-Host -Prompt "* Nothing to do! Press Enter to exit"
	Exit 1
}

Write-Host("* Here are the available packages:")
for ($i = 0; $i -lt $AVAILABLE_PKGS.Length; $i++) {
	Write-Host([string]$i + ": " + $AVAILABLE_PKGS[$i])
}

$j = Read-Host -Prompt "* Enter the number corresponding to the one you want to install"

# Check if that was a sane reply...
# Try to cast to an int first...
$j = [int]$j
# And check if that was successful.
if (-NOT ($j -is [int])) {
	Write-Host("That wasn't a number!")
	Read-Host -Prompt "* No changes were made! Press Enter to exit"
	Exit 1
}

if ($j -lt 0 -OR $j -ge $AVAILABLE_PKGS.Length) {
	Write-Host("That number was out of range!")
	Read-Host -Prompt "* No changes were made! Press Enter to exit"
	Exit 1
}

# Prevent Nickel from scanning hidden *nix directories (FW 4.17+)
Write-Host("* Preventing Nickel from scanning hidden directories . . .")
$KOBO_CONF=$KOBO_DIR + "\Kobo" + "\Kobo eReader.conf"
@'


[FeatureSettings]
ExcludeSyncFolders=(\\.(?!kobo|adobe).+|([^.][^/]*/)+\\..+)

'@ | Add-Content -NoNewline -Path $KOBO_CONF

# We've got a Kobo, we've got a package, let's go!
if ($AVAILABLE_PKGS[$j] -eq "KFMon-Uninstaller.zip") {
	Write-Host("* Uninstalling KFMon . . .")
	$KOBO_DEST=$KOBO_DIR
	#Write-Host("Expand-Archive " + $AVAILABLE_PKGS[$j] + " -DestinationPath " + $KOBO_DEST + " -Force")
	Expand-Archive $AVAILABLE_PKGS[$j] -DestinationPath $KOBO_DEST -Force
} else {
	Write-Host("* Installing " + $AVAILABLE_PKGS[$j] + " . . .")
	$KOBO_DEST=$KOBO_MOUNTPOINT + ":\"
	#Write-Host("Expand-Archive " + $AVAILABLE_PKGS[$j] + " -DestinationPath " + $KOBO_DEST + " -Force")
	Expand-Archive $AVAILABLE_PKGS[$j] -DestinationPath $KOBO_DEST -Force
}

# Much like in the error paths, draw a final prompt so that the window stays up...
if ($?) {
	Write-Host("* Installation successful!")
	Write-Host("* Please make sure to unplug your device safely!")
	Read-Host -Prompt "Press Enter to exit"
} else {
	Read-Host -Prompt "* Installation FAILED! No cleanup will be done! Press Enter to exit"
}
