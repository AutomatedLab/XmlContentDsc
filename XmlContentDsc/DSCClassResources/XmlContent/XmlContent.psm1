enum Ensure
{
    Absent
    Present
}

[DscResource()]
class XmlContent
{
    [DscProperty(Key)]
    [string]$Path
     
    [DscProperty(Key)]
    [string]$XPath

    [DscProperty()]
    [hashtable]$Attributes
    
    [DscProperty()]
    [hashtable]$Namespaces
     
    [DscProperty(Mandatory)]
    [Ensure]$Ensure
    
    XmlContent() {
        if (-not $this.Namespaces) {
            $this.Namespaces = @{}
        }
    }

    [void] Set()
    {
        Write-Verbose "Reading XML file from path '$($this.Path)"
        $xml = [xml](Get-Content -Path $this.Path)
        
        if ($this.Ensure -eq 'Present')
        {
            $param = @{
                XPath  = $this.XPath
            }
            if ($this.Namespaces.Count) {
                $param.Add('Namespace', $this.Namespaces)
            }
            Write-Verbose "Looking for element '$($this.XPath)'"
            $element = $xml | Select-Xml @param -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Node

            if (-not $element) {
                Write-Verbose "The element '$($this.XPath)' could not be found in XML file '$($this.Path)'."
            }
            
            $parentXPath = $this.XPath.Substring(0, $this.XPath.LastIndexOf('/'))
            $param = @{
                XPath  = $parentXPath
            }
            if ($this.Namespaces.Count) {
                $param.Add('Namespace', $this.Namespaces)
            }
            
            Write-Verbose "Looking for the elemen's parent node. XPath is '$parentXPath'"
            $parent = $xml | Select-Xml @param | Select-Object -ExpandProperty Node
            if (-not $parent) {
                Write-Error "The parent node '$parentXPath' could not be found in XML file '$($this.Path)'."
                return
            }

            if (-not $element -and $this.Ensure -eq 'Present')
            {                
                Write-Verbose "The element could not be found but the parent node and Ensure is set to 'Present'"
                $newElementName = $this.XPath.Substring($this.XPath.LastIndexOf('/') + 1)
                Write-Verbose "`tNew element name is '$newElementName'"
                $element = $parent.OwnerDocument.CreateElement($newElementName)
                $parent.AppendChild($element)
            }
            
            if ($this.Attributes)
            {
                foreach ($kvp in $this.Attributes.GetEnumerator())
                {
                    $attribute = $element.Attributes | Where-Object Name -eq $kvp.Name
                    if ($attribute)
                    {
                        if ($attribute.Value -eq $kvp.Value)
                        {
                            continue
                        }
                        else
                        {
                            $attribute.Value = $kvp.Value
                        }
                    }
                    else
                    {
                        $attribute = $parent.OwnerDocument.CreateAttribute($kvp.Name)
                        $attribute.Value = $kvp.Value
                        $element.Attributes.Append($attribute)
                    }
                }
                
                $attributesCollection = New-Object System.Xml.XmlAttribute[]($element.Attributes.Count)
                $element.Attributes.CopyTo($attributesCollection, 0)
                
                foreach ($attribute in $attributesCollection)
                {
                    if (-not $this.Attributes.ContainsKey($attribute.Name))
                    {
                        $element.Attributes.RemoveNamedItem($attribute.Name)
                    }
                }
            }
        }
        else
        {
            $param = @{
                XPath  = $this.XPath
            }
            if ($this.Namespaces.Count) {
                $param.Add('Namespace', $this.Namespaces)
            }
            $element = $xml | Select-Xml @param | Select-Object -ExpandProperty Node
            if ($element)
            {
                $element.ParentNode.RemoveChild($element)
            }
        }
        
        $xml.Save($this.Path)
    }

    [bool] Test()
    {
        Write-Verbose 'Receiving current state'
        $currentState = $this.Get()
        Write-Verbose 'Current state recevied'
        
        $attributesEqual = if ($this.Attributes)
        {
            Compare-Hashtable -Reference $this.Attributes -Difference $currentState.Attributes
        }
        else
        {
            $true
        }
        Write-Verbose "Attributes equal: $attributesEqual"
        
        return ($this.Ensure -eq $currentState.Ensure) -band $attributesEqual
    }

    [XmlContent]Get()
    {
        $currentState = New-Object XmlContent
        $currentState.Path = $this.Path
        $currentState.XPath = $this.XPath
        $currentState.Attributes = @{}

        Write-Verbose "Reading XML file from path '$($this.Path)"
        $xml = [xml](Get-Content -Path $this.Path)
        if (-not $xml) {
            Write-Error "No xml content"
        }
        $param = @{
            XPath  = $this.XPath
        }
        if ($this.Namespaces.Count) {
            $param.Add('Namespace', $this.Namespaces)
        }
        $node = $xml | Select-Xml @param | Select-Object -ExpandProperty Node
        
        if (-not $node) {
            return $currentState 
        }
        
        if ($node)
        {
            $currentState.Ensure = 'Present'
        }
        else
        {
            $currentState.Ensure = 'Absent'
        }
        
        foreach ($attribute in $node.Attributes)
        {
            $currentState.Attributes.Add($attribute.Name, $attribute.Value)
        }
        
        return $currentState
    }
}