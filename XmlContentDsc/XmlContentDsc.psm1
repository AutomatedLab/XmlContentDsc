function Compare-Hashtable
{
    param(
        [Parameter(Mandatory)]
        [hashtable]$Reference,

        [Parameter(Mandatory)]
        [hashtable]$Difference
    )
    
    foreach ($kvp in $Reference.GetEnumerator())
    {
        if (-not $Difference.ContainsKey($kvp.Name))
        {
            return $false
        }
        if ($Reference[$kvp.Name] -ne $Difference[$kvp.Name])
        {
            return $false
        }
    }

    foreach ($kvp in $Difference.GetEnumerator())
    {
        if (-not $Reference.ContainsKey($kvp.Name))
        {
            return $false
        }
        if ($Difference[$kvp.Name] -ne $Reference[$kvp.Name])
        {
            return $false
        }
    }
    
    return $true
}

function Convert-CimInstanceArrayToHashtable
{
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ciminstance[]]$CimInstance
    )
    
    begin {
        $h = @{}
    }
    
    process {
        foreach ($ci in $CimInstance) {
            if ($ci.CimClass.CimClassName -ne 'MSFT_KeyValuePair') {
                Write-Error "Cannot convert CimInstance of class '$($ci.CimClass.CimClassName)' into a hashtable. The instance type required is 'MSFT_KeyValuePair'"
                return
            }
            $h."$($ci.Key)" = $ci.Value
        }
    }
    
    end {
        return $h
    }
}
