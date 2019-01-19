enum Ensure {
    Absent
    Present
}

[DscResource()]
class XmlFileContentResource {
    [DscProperty(Key)]
    [string]$Path
     
    [DscProperty(Key)]
    [string]$XPath

    [DscProperty()]
    [hashtable]$Attributes
     
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [void] Set() {
        $xml = [xml](Get-Content -Path $this.Path)
        
        if ($this.Ensure -eq 'Present') {
            $element = $xml | Select-Xml -XPath $this.XPath | Select-Object -ExpandProperty Node
            $parentXPath = $this.XPath.Substring(0, $this.XPath.LastIndexOf('/'))
            $parent = $xml | Select-Xml -XPath $parentXPath

            if (-not $element) {                
                $newElementName = $this.XPath.Substring($this.XPath.LastIndexOf('/') + 1)
                $element = $parent.Node.OwnerDocument.CreateElement($newElementName)
                $parent.Node.AppendChild($element)
            }
            
            if ($this.Attributes) {
                foreach ($kvp in $this.Attributes.GetEnumerator()) {
                    $attribute = $element.Attributes | Where-Object Name -eq $kvp.Name
                    if ($attribute) {
                        if ($attribute.Value -eq $kvp.Value) {
                            continue
                        }
                        else {
                            $attribute.Value = $kvp.Value
                        }
                    }
                    else {
                        $attribute = $parent.Node.OwnerDocument.CreateAttribute($kvp.Name)
                        $attribute.Value = $kvp.Value
                        $element.Attributes.Append($attribute)
                    }
                }
                
                $attributesCollection = New-Object System.Xml.XmlAttribute[]($element.Attributes.Count)
                $element.Attributes.CopyTo($attributesCollection, 0)
                
                foreach ($attribute in $attributesCollection) {
                    if (-not $this.Attributes.ContainsKey($attribute.Name)) {
                        $element.Attributes.RemoveNamedItem($attribute.Name)
                    }
                }
            }
        }
        else {
            $element = $xml | Select-Xml -XPath $this.XPath
            if ($element) {
                $element.Node.ParentNode.RemoveChild($element.Node)
            }
        }
        
        $xml.Save($this.Path)
    }

    [bool] Test() {
        $currentState = $this.Get()
        
        $attributesEqual = if ($this.Attributes) {
            Compare-Hashtable -Hashtable1 $this.Attributes -Hashtable2 $currentState.Attributes
        }
        else {
            $true
        }
        
        return ($this.Ensure -eq $currentState.Ensure) -band $attributesEqual
    }

    [XmlFileContentResource]Get() {
        $currentState = New-Object XmlFileContentResource
        $currentState.Path = $this.Path
        $currentState.XPath = $this.XPath
        $currentState.Attributes = @{}

        $xml = [xml](Get-Content -Path $this.Path)
        $node = $xml | Select-Xml -XPath $this.XPath | Select-Object -ExpandProperty Node
        
        if ($node) {
            $currentState.Ensure = 'Present'
        }
        else {
            $currentState.Ensure = 'Absent'
        }
        
        foreach ($attribute in $node.Attributes) {
            $currentState.Attributes.Add($attribute.Name, $attribute.Value)
        }
        
        return $currentState
    }
}

function Compare-Hashtable {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Hashtable1,

        [Parameter(Mandatory)]
        [hashtable]$Hashtable2
    )
    
    foreach ($kvp in $Hashtable1.GetEnumerator()) {
        if (-not $Hashtable2.ContainsKey($kvp.Name)) {
            return $false
        }
        if ($Hashtable1[$kvp.Name] -ne $Hashtable2[$kvp.Name]) {
            return $false
        }
    }

    foreach ($kvp in $Hashtable2.GetEnumerator()) {
        if (-not $Hashtable1.ContainsKey($kvp.Name)) {
            return $false
        }
        if ($Hashtable2[$kvp.Name] -ne $Hashtable1[$kvp.Name]) {
            return $false
        }
    }
    
    return $true
}

#$x = New-Object XmlFileContentResource
#$x.Path = 'D:\web.config'
#$x.Ensure = 'Present'
#$x.XPath = '/configuration/appSettings/Test1'
#$x.Attributes = @{ TestValue2 = '123'; Name = 'Hans' }
#
#if (-not $x.Test())
#{
#    Write-Host 'invoking set'
#    $x.Set()
#}