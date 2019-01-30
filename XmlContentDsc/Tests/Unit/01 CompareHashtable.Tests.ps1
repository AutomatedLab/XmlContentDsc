Describe 'Compare-Hashtable' -Tags 'UnitTest' {

    Context Parameters {

        It 'Wrong parameter type for reference' {
            $r = 123
            $d = @{}
            { Compare-Hashtable -Reference $r -Difference $d } | Should -Throw
        }

        It 'Wrong parameter type for difference' {
            $r = @{}
            $d = 123
            { Compare-Hashtable -Reference $r -Difference $d } | Should -Throw
        }
    }

    Context Comparison {
        It '2 empty hash tables return $true' {
            $r = @{}
            $d = @{}
            Compare-Hashtable -Reference $r -Difference $d | Should -Be $true
        }

        It 'Reference has a key that is not in difference' {
            $r = @{ Key = '' }
            $d = @{}
            Compare-Hashtable -Reference $r -Difference $d | Should -Be $false
        }

        It 'Difference has a key that is not in reference' {
            $r = @{}
            $d = @{ Key = '' }
            Compare-Hashtable -Reference $r -Difference $d | Should -Be $false
        }

        It 'Both hash tables have the same key but different values 1' {
            $r = @{ Key = '123'}
            $d = @{ Key = '1234' }
            Compare-Hashtable -Reference $r -Difference $d | Should -Be $false
        }

        It 'Both hash tables have the same key but different values 2' {
            $r = @{ Key = '1234'}
            $d = @{ Key = '123' }
            Compare-Hashtable -Reference $r -Difference $d | Should -Be $false
        }

        It 'Both hash tables have the same key and value (int)' {
            $r = @{ Key = 1234 }
            $d = @{ Key = 1234 }
            Compare-Hashtable -Reference $r -Difference $d | Should -Be $true
        }

        It 'Both hash tables have the same key and value (string)' {
            $r = @{ Key = '1234' }
            $d = @{ Key = '1234' }
            Compare-Hashtable -Reference $r -Difference $d | Should -Be $true
        }
    }
}