function Invoke-SQL {
    param(
        [string]$dataSource = ".\SQLEXPRESS",
        [string]$database = "MasterData",
        [string]$sqlCommand = $(throw "Please specify a query."),
        $Credential = [System.Management.Automation.PSCredential]::Empty,
        [Switch]$ConvertFromDataRow
    )

    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
        $connectionString = "Server=$dataSource;Database=$database;User Id=$($Credential.UserName);Password=$($Credential.GetNetworkCredential().password);"
    } else {
        $connectionString = "Data Source=$dataSource; Integrated Security=SSPI; Initial Catalog=$database"
    }

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()
    
    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    
    $connection.Close()
    
    if ($ConvertFromDataRow) {
        $dataSet.Tables | ConvertFrom-DataRow
    } else {
        $dataSet.Tables
    }
}

function Invoke-SQLODBC {
    param (
        [string]$DataSourceName,
        [string]$SQLCommand = $(throw "Please specify a query.")
    )
    $ConnectionString = "DSN=$DataSourceName"

    $Connection = new-object System.Data.Odbc.OdbcConnection($ConnectionString)
    $Command = new-object System.Data.Odbc.OdbcCommand($SQLCommand,$Connection)
    $Connection.Open()
    
    $Adapter = New-Object System.Data.Odbc.OdbcDataAdapter $Command
    $Dataset = New-Object System.Data.DataSet
    $Adapter.Fill($Dataset) | Out-Null
    
    $Connection.Close()
    $DataSet.Tables 
}

function ConvertFrom-DataRow {
    param(
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        $DataRow
    )
    process {
        $DataRowProperties = $DataRow | GM -MemberType Properties | select -ExpandProperty name
        $DataRowWithLimitedProperties = $DataRow | select $DataRowProperties
        $DataRowAsPSObject = $DataRowWithLimitedProperties | % { $_ | ConvertTo-Json | ConvertFrom-Json }
#        if($DataRowAsPSObject | GM | where membertype -NE "Method") {
#            $DataRowAsPSObject
#        }

        $DataRowAsPSObject
    }
}

