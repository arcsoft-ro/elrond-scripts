Import-Module "$PSScriptRoot/../.modules/ErdCore/ErdCore.psd1"
Import-Module "$PSScriptRoot/../.modules/ErdIO/ErdIO.psd1"

$global:testDir = '/test-data'

describe "Test-FileIsReadable" {

    it "Should return true for readable file $testDir/file-readable.txt" {
		$testDir = $PSScriptRoot + '/.tests/test-data'
		Test-FileIsReadable -Path "$global:testDir/file-readable.txt" | Should -Be $true
    }

	it "Should return false for non readable file $testDir/file-no-access.txt" {
        Test-FileIsReadable -Path "$global:testDir/file-no-access.txt" | Should -Be $false
    }

	it "Should return false for non existing file" {
        Test-FileIsReadable -Path "$global:testDir/non-existing-file" | Should -Be $false
    }
}

describe "Test-FileIsWritable" {

    it "Should return true for writeable file $testDir/file-writable.txt" {
		Test-FileIsWritable -Path "$global:testDir/file-writable.txt" | Should -Be $true
    }

	it "Should return false for non writeable file $testDir/file-no-access.txt" {
        Test-FileIsWritable -Path "$global:testDir/file-no-access.txt" | Should -Be $false
    }

    it "Should return true for non existing file" {
		$filePath = "$global:testDir/non-existing-file"
        Test-FileIsWritable -Path $filePath | Should -Be $true
		Remove-Item $filePath
    }
}

describe "Test-DirIsWritable"{

	it "Should return true for writable directory $testDir"{
		Test-DirIsWritable -Path "$global:testDir" | Should -Be $true
	}

	it "Should return false for non writable directory $testDir/dir-no-access"{
		Test-DirIsWritable -Path "$global:testDir/dir-no-access" | Should -Be $false
	}

	it "Should return false for non existing directory"{
		Test-DirIsWritable -Path "$global:testDir/non-existing-directory" | Should -Be $false
	}

}

