Import-Module -Force InvokeSQL

Describe "InvokeSQL" {
    $DataRows = Invoke-MSSQL -Server sql -database master -SQLCommand "select * from sys.databases" -ConvertFromDataRow:$false
    It "GetInitialValue" {
        1..10  | % {}
    }
    It "ConvertFrom-DataRow" {
        1..10  | % {$DataRows | ConvertFrom-DataRow}
    }
    It "ConvertFrom-DataRow2" {
        1..10 | % {$DataRows | ConvertFrom-DataRow2}
    }
    It "ConvertFrom-DataRowHashToPSCustom" {
        1..10 | % {$DataRows | ConvertFrom-DataRowHashToPSCustom}
    }
    It "ConvertFrom-DataRowHashToPSCustomCSharp" {
        1..10 | % {$DataRows | ConvertFrom-DataRowHashToPSCustomCSharp}
    }
    It "ConvertFrom-DataRow4" {
        1..10 | % {$DataRows | ConvertFrom-DataRow4}
    }
    It "CompareResults" {
        "var"
        Compare-Object ($DataRows | ConvertFrom-DataRow)[0].PSObject.Properties.name ($DataRows | ConvertFrom-DataRow2)[0].PSObject.Properties.name |
        should -BeNullOrEmpty
    }
}