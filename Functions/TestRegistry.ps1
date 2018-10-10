#
function New-TestRegistry
{
    param(
        [Switch]
        $PassThru,

        [string]
        $Path
    )

    if ($Path -notmatch '\S')
    {
        $directory = New-RandomTempRegistry
    }
    else
    {
        if (-not (& $SafeCommands['Test-Path'] -Path $Path))
        {
            $null = & $SafeCommands['New-Item'] -Path $Path -Force
        }

        $directory = & $SafeCommands['Get-Item'] $Path
    }

    $DriveName = "TestRegistry"

    #setup the test drive
    if ( -not (& $SafeCommands['Test-Path'] "${DriveName}:\") )
    {
        $null = & $SafeCommands['New-PSDrive'] -Name $DriveName -PSProvider Registry -Root $directory -Scope Global -Description "Pester test drive"
    }

    #publish the global TestRegistry variable used in few places within the module
    if (-not (& $SafeCommands['Test-Path'] "Variable:Global:$DriveName"))
    {
        & $SafeCommands['New-Variable'] -Name $DriveName -Scope Global -Value $directory
    }

    if ( $PassThru )
    {
        & $SafeCommands['Get-PSDrive'] -Name $DriveName
    }
}


function Clear-TestRegistry
{
    param(
        [String[]]
        $Exclude
    )

    $Path = (& $SafeCommands['Get-PSDrive'] -Name TestRegistry).Root

    if (& $SafeCommands['Test-Path'] -Path $Path )
    {
        #Get-ChildItem -Exclude did not seem to work with full paths
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path |
            & $SafeCommands['Sort-Object'] -Descending  -Property "FullName" |
            & $SafeCommands['Where-Object'] { $Exclude -NotContains $_.FullName } |
            & $SafeCommands['Remove-Item'] -Force -Recurse
    }
}

function Get-TestRegistryChildItem {
    $Path = (& $SafeCommands['Get-PSDrive'] -Name TestRegistry).Root
    if (& $SafeCommands['Test-Path'] -Path $Path )
    {
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path
    }
}

function New-RandomTempRegistry
{
    do
    {
        $tempPath = Get-TempRegistry
        $Path = & $SafeCommands['Join-Path'] -Path $tempPath -ChildPath ([Guid]::NewGuid())
    } until (-not (& $SafeCommands['Test-Path'] -Path $Path ))

    & $SafeCommands['New-Item'] -Path $Path -Force
}

function Remove-TestRegistry
{

    $DriveName = "TestRegistry"
    $Drive = & $SafeCommands['Get-PSDrive'] -Name $DriveName -ErrorAction $script:IgnoreErrorPreference
    $Path = ($Drive).Root

    if ($pwd -like "$DriveName*" )
    {
        #will staying in the test drive cause issues?
        #TODO review this
        & $SafeCommands['Write-Warning'] -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ( $Drive )
    {
        $Drive | & $SafeCommands['Remove-PSDrive'] -Force #This should fail explicitly as it impacts future pester runs
    }

    if (& $SafeCommands['Test-Path'] -Path $Path)
    {
        & $SafeCommands['Remove-Item'] -Path $Path -Force -Recurse
    }

    if (& $SafeCommands['Get-Variable'] -Name $DriveName -Scope Global -ErrorAction $script:IgnoreErrorPreference)
    {
        & $SafeCommands['Remove-Variable'] -Scope Global -Name $DriveName -Force
    }
}

function Initialize-TestRegistry
{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Key", "Property")]
        $ObjectType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [System.String]
        $PropertyName,

        [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "Qword", "Unknown")]
        $PropertyType,

        $Value,

        [switch]
        $PassThru
    )

    Assert-DescribeInProgress -CommandName Setup

    $TestRegistryName = & $SafeCommands['Get-PSDrive'] TestRegistry |
        & $SafeCommands['Select-Object'] -ExpandProperty Root

    $Path = $Path.Replace(":", "")

    switch ($ObjectType)
    {
        "Key"
        {
            $item = & $SafeCommands['New-Item'] -Path "${TestRegistryName}\${Path}" -Value $Value -Force
        }
        "Property"
        {
            $item = & $SafeCommands['New-ItemProperty'] -Name $PropertyName -Path "${TestRegistryName}\${Path}" -Value $Value -PropertyType $PropertyType -Force
        }

    }

    if ($PassThru)
    {
        return $item
    }
}
