function Invoke-SQL {
    param(
        [string]$dataSource = ".\SQLEXPRESS",
        [string]$database = "MasterData",
        [string]$sqlCommand = $(throw "Please specify a query."),
        $Credential = [System.Management.Automation.PSCredential]::Empty,
        [Switch]$ConvertFromDataRow
    )
    Write-Warning "Invoke-SQL retained for backwards compatibility, please use Invoke-MSSQL instead"
    $ConnectionString = New-MSSQLConnectionString -Server $dataSource -Database $database -Credential $Credential
    Invoke-SQLGeneric -DatabaseEngineClassMapName MSSQL -ConnectionString $ConnectionString -SQLCommand $sqlCommand -ConvertFromDataRow:$ConvertFromDataRow
}

function ConvertTo-MSSQLConnectionString {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$Server,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$Database,
        [Parameter(ValueFromPipelineByPropertyName)]$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    process {
        New-MSSQLConnectionString @PSBoundParameters
    }
}

function New-MSSQLConnectionString {
    param (
        [Parameter(Mandatory)]$Server,
        [Parameter(Mandatory)]$Database,
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
        "Server=$Server;Database=$Database;User Id=$($Credential.UserName);Password=$($Credential.GetNetworkCredential().password);"
    } else {
        "Data Source=$Server; Integrated Security=SSPI; Initial Catalog=$Database"
    }
}


function Invoke-SQLODBC {
    param (
        [string]$DataSourceName,
        [string]$SQLCommand = $(throw "Please specify a query."),
        [Switch]$ConvertFromDataRow
    )
    $ConnectionString = "DSN=$DataSourceName"
    Invoke-SQLGeneric -ConnectionString $ConnectionString -SQLCommand $SQLCommand -DatabaseEngineClassMapName ODBC -ConvertFromDataRow:$ConvertFromDataRow
}

function ConvertFrom-DataRow {
    param(
        [Parameter(
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        $DataRow
    )
    begin {
        #Based on Dave Wyatt's code https://powershell.org/forums/topic/dealing-with-dbnull/
        $cSharp = @"
using System;
using System.Data;
using System.Management.Automation;

public class DBNullScrubber
{
    public static PSObject DataRowToPSObject(DataRow row)
    {
        PSObject psObject = new PSObject();

        if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
        {
            foreach (DataColumn column in row.Table.Columns)
            {
                Object value = null;
                if (!row.IsNull(column))
                {
                    value = row[column];
                }

                psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
            }
        }

        return psObject;
    }
}
"@      
    if (-not $Script:DBNullScrubberAdded) {
            $Script:DBNullScrubberAdded = $true
            Add-Type -TypeDefinition $cSharp -ReferencedAssemblies 'System.Data','System.Xml'
        }   
    }
    process {
        [DBNullScrubber]::DataRowToPSObject($DataRow)
    }
}

function ConvertFrom-DataRow4 {
    param(
        [Parameter(
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        $DataRow
    )
    process {
        $Names = $DataRow.PSObject.Properties |
        Where-Object Name -NotIn RowError, RowState, Table, HasErrors, ItemArray |
        Select-Object -ExpandProperty Name
    }
}

function ConvertFrom-DataRowHashToPSCustom {
    param(
        [Parameter(
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        $DataRow
    )
    process {
        $PropertyNames = $DataRow.PSObject.Properties.Name
        $DataRowProperties = $PropertyNames.Where({$_ -notin "RowError", "RowState", "Table", "HasErrors", "ItemArray"})
        $Hash = [Ordered]@{}
        foreach ($PropertyName in $DataRowProperties) {
            $Hash.Add($PropertyName, $DataRow.$PropertyName)
        }
        [PSCustomObject]$Hash
    }
}

function ConvertFrom-DataRowHashToPSCustomCSharp {
    param(
        [Parameter(
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        $DataRow
    )
    begin {
        $cSharp = @"
using System;
using System.Data;
using System.Management.Automation;

public class DBNullScrubber
{
    public static PSObject DataRowToPSObject(DataRow row)
    {
        PSObject psObject = new PSObject();

        if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
        {
            foreach (DataColumn column in row.Table.Columns)
            {
                Object value = null;
                if (!row.IsNull(column))
                {
                    value = row[column];
                }

                psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
            }
        }

        return psObject;
    }
}
"@      
    if (-not $Script:DBNullScrubberAdded) {
            $Script:DBNullScrubberAdded = $true
            Add-Type -TypeDefinition $cSharp -ReferencedAssemblies 'System.Data','System.Xml'
        }   
    }
    process {
        [DBNullScrubber]::DataRowToPSObject($DataRow)
    }
}

function ConvertFrom-DataRow2 {
    param(
        [Parameter(
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        $DataRow
    )
    process {
        $PropertyNames = $DataRow.PSObject.Properties.Name
        $DataRowProperties = $PropertyNames.Where({$_ -notin "RowError", "RowState", "Table", "HasErrors", "ItemArray"})
        $Object = New-Object PSObject
        foreach ($PropertyName in $DataRowProperties) {
            $Property = New-Object System.Management.Automation.PSNoteProperty -ArgumentList $PropertyName, $DataRow.$PropertyName
            $Object.PSObject.Properties.Add($Property)
        }
        $Object
        
        #$Object = '' | Select-Object $DataRowProperties
        #foreach ($PropertyName in $DataRowProperties) {
        #    $Object.$PropertyName = $DataRow.$PropertyName
        #}
        #$Object


        
#
        #$DataRowWithLimitedProperties = $DataRow | select $DataRowProperties
#
        #$DataRowWithLimitedProperties = $DataRow | select -ExcludeProperty RowError, RowState, Table, HasErrors, ItemArray
        #$DataRowAsPSObject = $DataRowWithLimitedProperties | % { $_ | ConvertTo-Json | ConvertFrom-Json }
        #$DataRowAsPSObject

        #$DataRow |
        #Select-Object -Property * -ExcludeProperty RowError, RowState, Table, HasErrors, ItemArray
    }
}

function Invoke-MSSQL {
    param(
        [Parameter(Mandatory,ParameterSetName="NoConnectionString")]$Server,
        [Parameter(Mandatory,ParameterSetName="NoConnectionString")]$Database,
        [Parameter(ParameterSetName="NoConnectionString")]$Credential = [System.Management.Automation.PSCredential]::Empty,
        [Parameter(Mandatory,ParameterSetName="ConnectionString")][string]$ConnectionString,
        [Parameter(Mandatory)][string]$SQLCommand,
        [Switch]$ConvertFromDataRow
    )
    if (-not $ConnectionString) {
        $ConnectionString = New-MSSQLConnectionString -Server $Server -Database $Database -Credential $Credential
        Invoke-SQLGeneric -ConnectionString $ConnectionString -SQLCommand $SQLCommand -ConvertFromDataRow:$ConvertFromDataRow -DatabaseEngineClassMapName MSSQL
    } else {
        Invoke-SQLGeneric -DatabaseEngineClassMapName MSSQL @PSBoundParameters
    }
}

function Install-InvokeSQLAnywhereSQL {
    choco install sqlanywhereclient -version 12.0.1 -y
}

function ConvertTo-SQLAnywhereConnectionString {
    param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$Host,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$DatabaseName,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$ServerName,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$UserName,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$Password
    )
    "UID=$UserName;PWD=$Password;Host=$Host;DatabaseName=$DatabaseName;ServerName=$ServerName"
}

$DatabaseEngineClassMap = [PSCustomObject][Ordered]@{
    Name = "SQLAnywhere"
    NameSpace = "iAnywhere.Data.SQLAnywhere"
    Connection = "SAConnection"
    Command = "SACommand"
    Adapter = "SADataAdapter"
    AddTypeScriptBlock = {Add-iAnywhereDataSSQLAnywhereType}
},
[PSCustomObject][Ordered]@{
    Name = "Oracle"
    NameSpace = "Oracle.ManagedDataAccess.Client"
    Connection = "OracleConnection"
    Command = "OracleCommand"
    Adapter = "OracleDataAdapter"
    AddTypeScriptBlock = {Add-OracleManagedDataAccessType}
},
[PSCustomObject][Ordered]@{
    Name = "MSSQL"
    NameSpace = "system.data.sqlclient"
    Connection = "SQLConnection"
    Command = "SQLCommand"
    Adapter = "SQLDataAdapter"
},
[PSCustomObject][Ordered]@{
    Name = "ODBC"
    NameSpace = "System.Data.Odbc"
    Connection = "OdbcConnection"
    Command = "OdbcCommand"
    Adapter = "OdbcDataAdapter"
},
[PSCustomObject][Ordered]@{
    Name = "ASE"
    NameSpace = "AdoNetCore.AseClient"
    Connection = "AseConnection"
    Command = "AseCommand"
    Adapter = "AseDataAdapter"
    #Add-Type -Path /usr/local/share/PackageManagement/NuGet/Packages/AdoNetCore.AseClient.0.10.1/lib/netcoreapp2.0/AdoNetCore.AseClient.dll
}


function Get-DatabaseEngineClassMap {
    param (
        [Parameter(Mandatory)]$Name
    )
    $DatabaseEngineClassMap | where Name -EQ $Name
}

function Add-iAnywhereDataSSQLAnywhereType {
    Add-Type -AssemblyName "iAnywhere.Data.SQLAnywhere, Version=12.0.1.36052, Culture=neutral, PublicKeyToken=f222fc4333e0d400"
}

function Invoke-SQLGeneric {
    param(
        [Parameter(Mandatory)][string]$ConnectionString,
        [Parameter(Mandatory)][string]$SQLCommand,
        [Parameter(Mandatory)][ValidateSet("SQLAnywhere","Oracle","MSSQL","ODBC","ASE")]$DatabaseEngineClassMapName,
        [Switch]$ConvertFromDataRow
    )
    $ClassMap = Get-DatabaseEngineClassMap -Name $DatabaseEngineClassMapName
    $NameSpace = $ClassMap.NameSpace
    if ($ClassMap.AddTypeScriptBlock) { & $ClassMap.AddTypeScriptBlock }

    $Connection = New-Object -TypeName "$NameSpace.$($ClassMap.Connection)" $ConnectionString
    $Command = New-Object "$NameSpace.$($ClassMap.Command)" $SQLCommand,$Connection
    $Connection.Open()
    
    $Adapter = New-Object "$NameSpace.$($ClassMap.Adapter)" $Command
    $Dataset = New-Object System.Data.DataSet

    if ($Global:LogSQL) {
        $StopWatch = [Diagnostics.Stopwatch]::StartNew()
        $Adapter.Fill($DataSet) | Out-Null
        $StopWatch.Stop()
    } else {
        $Adapter.Fill($DataSet) | Out-Null
    }
    
    $Connection.Close()
    
    if ($ConvertFromDataRow -and ($DataSet.Tables.DataRow -or $DataSet.Tables.Rows)) {
        $DataSet.Tables.Rows | ConvertFrom-DataRow
    } elseif ($DataSet.Tables.Rows) {
        $DataSet.Tables.Rows
    }

    New-SQLCallLog -ConnectionString $ConnectionString -Command $SQLCommand -TimeSpan $StopWatch.Elapsed
}

function New-SQLCallLog {
    param (
        $ConnectionString,
        $Command,
        $TimeSpan
    )
    if (-not $Script:SQLCallLog) {
        $Script:SQLCallLog = New-Object System.Collections.ArrayList
    }
    
    $Script:SQLCallLog.Add(($PSBoundParameters | ConvertFrom-PSBoundParameters)) | Out-Null
}

function Get-SQLCallLog {
    $Script:SQLCallLog
}

function Invoke-SQLAnywhereSQL {
    param(
        [Parameter(Mandatory)][string]$ConnectionString,
        [Parameter(Mandatory)][string]$SQLCommand,
        [Switch]$ConvertFromDataRow
    )
    Invoke-SQLGeneric @PSBoundParameters -DatabaseEngineClassMapName = "SQLAnywhere"
}

function Install-InvokeOracleSQL {
    $ModulePath = (Get-Module -ListAvailable InvokeSQL).ModuleBase
    Set-Location -Path $ModulePath

    if ($PSVersionTable.Platform -ne "Unix") {
        $SourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
        $TargetNugetExe = ".\nuget.exe"
        Invoke-WebRequest $sourceNugetExe -OutFile $targetNugetExe
        .\nuget.exe install Oracle.ManagedDataAccess
        Remove-Item -Path $TargetNugetExe
    } elseif ($PSVersionTable.Platform -eq "Unix") {
        nuget install Oracle.ManagedDataAccess.Core -Version 2.12.0-beta2
    }
}

function Add-OracleManagedDataAccessType {
    if (-not ([System.Management.Automation.PSTypeName]'Oracle.ManagedDataAccess.Types.INullable').Type) {
        $ModulePath = (Get-Module -ListAvailable InvokeSQL).ModuleBase
        $OracleManagedDataAccessDirectory = Get-ChildItem -Directory -Path $ModulePath | where Name -Match Oracle
        $DllFile = Get-ChildItem -Path $ModulePath\$OracleManagedDataAccessDirectory\lib\ -Recurse -File
        Add-Type -Path $DllFile.fullname
    }
}

function ConvertTo-OracleConnectionString {
    param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$Host,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$Port,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$Service_Name,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$UserName,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$Password,
        [Parameter(ValueFromPipelineByPropertyName)][string]$Protocol = "TCP"
    )
    "User Id=$UserName;Password=$Password;Data Source=(DESCRIPTION=(ADDRESS=(PROTOCOL=$Protocol)(HOST=$Host)(PORT=$Port))(CONNECT_DATA=(SERVICE_NAME=$Service_Name)));"
}

function Invoke-OracleSQL {
    param(
        [Parameter(Mandatory)][string]$ConnectionString,
        [Parameter(Mandatory)][string]$SQLCommand,
        [Switch]$ConvertFromDataRow
    )
    Invoke-SQLGeneric -DatabaseEngineClassMapName Oracle @PSBoundParameters
}

function Install-InvokeSQL {
    Install-InvokeOracleSQL
    Install-InvokeSQLAnywhereSQL
}

function ConvertTo-SQLArrayFromCSV{
    param(
        [parameter(mandatory)][PSCustomObject]$CSVObject,
        [parameter(mandatory)][string]$CSVColumnName
    )
    $Items = $CSVObject | where {$_.$CSVColumnName} | select -ExpandProperty $CSVColumnName

    "('$($Items -join "','")')"
}