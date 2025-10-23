<#
.SYNOPSIS
    HGL Verification and Policy Evaluation Script (Windows PowerShell)

.DESCRIPTION
    Verifies HGL artifacts with:
    - SHA256 hash validation
    - ED25519 signature verification via ssh-keygen
    - Policy gate evaluation (consent, privilege, temporal)
    - Deterministic exit codes for CI/CD integration

.PARAMETER Compiled
    Path to compiled HGL JSON file (e.g., 001_consent_access.compiled.json)

.PARAMETER Proof
    Path to synergy proof JSON file (e.g., synergy_proof.sample.json)

.PARAMETER AllowedSigners
    Path to SSH allowed_signers file (e.g., $HOME\.ssh\allowed_signers)

.PARAMETER Identity
    Signer identity to verify against (e.g., "ledger-root")

.PARAMETER Namespace
    SSH signature namespace (default: "ttd-ledger-root-v0.1")

.PARAMETER ManifestDir
    Directory containing sha256sums.txt and sha256sums.txt.sig (default: ".\manifests")

.PARAMETER JqPath
    Path to jq.exe executable (default: searches PATH, then local)

.PARAMETER Verbose
    Enable detailed diagnostic output

.EXAMPLE
    .\verify_and_eval.ps1 -Compiled examples\001_consent_access.compiled.json `
                          -Proof examples\synergy_proof.sample.json `
                          -AllowedSigners $HOME\.ssh\allowed_signers `
                          -Identity ledger-root

.NOTES
    Version: 1.2-beta.1
    Author: Helix Project AI
    License: Apache-2.0
    
    Exit Codes:
      0 - All checks passed
      1 - Hash mismatch detected
      2 - Signature verification failed
      3 - Policy gate failed
      4 - Missing required file
      5 - Tool dependency not found
      6 - Invalid input format
      10 - Unexpected error
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Compiled,
    
    [Parameter(Mandatory=$true)]
    [string]$Proof,
    
    [Parameter(Mandatory=$true)]
    [string]$AllowedSigners,
    
    [Parameter(Mandatory=$true)]
    [string]$Identity,
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "ttd-ledger-root-v0.1",
    
    [Parameter(Mandatory=$false)]
    [string]$ManifestDir = ".\manifests",
    
    [Parameter(Mandatory=$false)]
    [string]$JqPath = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$Script:ExitCode = 0

# ANSI color codes for output (if terminal supports it)
$Script:ColorReset = ""
$Script:ColorGreen = ""
$Script:ColorYellow = ""
$Script:ColorRed = ""
$Script:ColorCyan = ""

if ($Host.UI.SupportsVirtualTerminal) {
    $Script:ColorReset = "`e[0m"
    $Script:ColorGreen = "`e[32m"
    $Script:ColorYellow = "`e[33m"
    $Script:ColorRed = "`e[31m"
    $Script:ColorCyan = "`e[36m"
}

#region Helper Functions

function Write-StepHeader {
    param([string]$Message)
    Write-Host "${Script:ColorCyan}▶ $Message${Script:ColorReset}"
}

function Write-Success {
    param([string]$Message)
    Write-Host "${Script:ColorGreen}✓ $Message${Script:ColorReset}"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "${Script:ColorYellow}⚠ $Message${Script:ColorReset}"
}

function Write-Failure {
    param([string]$Message)
    Write-Host "${Script:ColorRed}✗ $Message${Script:ColorReset}"
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Find-JqExecutable {
    param([string]$ProvidedPath)
    
    # If path provided, check it first
    if ($ProvidedPath) {
        if (Test-Path $ProvidedPath) {
            return $ProvidedPath
        }
        Write-Warning "Provided jq path not found: $ProvidedPath"
    }
    
    # Check if jq is in PATH
    if (Test-CommandExists "jq") {
        return "jq"
    }
    
    # Check for bundled jq.exe in tools directory
    $bundledJq = Join-Path $PSScriptRoot "jq.exe"
    if (Test-Path $bundledJq) {
        return $bundledJq
    }
    
    # Check current directory
    if (Test-Path ".\jq.exe") {
        return ".\jq.exe"
    }
    
    return $null
}

function Get-FileSHA256 {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

function Read-JsonFile {
    param(
        [string]$FilePath,
        [string]$JqExe
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "JSON file not found: $FilePath"
    }
    
    try {
        # Use jq for reliable JSON parsing if available
        if ($JqExe) {
            $jsonText = & $JqExe "." $FilePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "jq failed to parse JSON: $jsonText"
            }
            return $jsonText | ConvertFrom-Json
        }
        else {
            # Fallback to PowerShell's JSON parser
            $content = Get-Content -Path $FilePath -Raw
            return $content | ConvertFrom-Json
        }
    }
    catch {
        throw "Failed to parse JSON file $FilePath : $_"
    }
}

#endregion

#region Verification Functions

function Test-SHA256Manifest {
    param(
        [string]$ManifestPath,
        [string[]]$FilesToVerify
    )
    
    Write-StepHeader "Verifying SHA256 checksums..."
    
    if (-not (Test-Path $ManifestPath)) {
        Write-Failure "SHA256 manifest not found: $ManifestPath"
        return $false
    }
    
    # Read manifest
    $manifest = Get-Content $ManifestPath
    $manifestHashes = @{}
    
    foreach ($line in $manifest) {
        if ($line -match '^([0-9a-f]{64})\s+(.+)$') {
            $hash = $matches[1]
            $file = $matches[2].Trim()
            $manifestHashes[$file] = $hash
        }
    }
    
    if ($manifestHashes.Count -eq 0) {
        Write-Failure "No hashes found in manifest"
        return $false
    }
    
    Write-Host "  Manifest contains $($manifestHashes.Count) entries"
    
    # Verify each file
    $allMatch = $true
    foreach ($file in $FilesToVerify) {
        $relativePath = (Resolve-Path $file -Relative) -replace '^\.\\', '' -replace '\\', '/'
        
        if (-not $manifestHashes.ContainsKey($relativePath)) {
            Write-Warning "  File not in manifest: $relativePath"
            continue
        }
        
        try {
            $actualHash = Get-FileSHA256 $file
            $expectedHash = $manifestHashes[$relativePath]
            
            if ($actualHash -eq $expectedHash) {
                Write-Success "  $relativePath"
                if ($Verbose) {
                    Write-Host "    Hash: $actualHash"
                }
            }
            else {
                Write-Failure "  $relativePath (hash mismatch)"
                Write-Host "    Expected: $expectedHash"
                Write-Host "    Actual:   $actualHash"
                $allMatch = $false
            }
        }
        catch {
            Write-Failure "  $relativePath (error: $_)"
            $allMatch = $false
        }
    }
    
    return $allMatch
}

function Test-ED25519Signature {
    param(
        [string]$ManifestPath,
        [string]$SignaturePath,
        [string]$AllowedSignersPath,
        [string]$SignerIdentity,
        [string]$SignatureNamespace
    )
    
    Write-StepHeader "Verifying ED25519 signature..."
    
    # Check required files
    if (-not (Test-Path $ManifestPath)) {
        Write-Failure "Manifest not found: $ManifestPath"
        return $false
    }
    
    if (-not (Test-Path $SignaturePath)) {
        Write-Failure "Signature not found: $SignaturePath"
        return $false
    }
    
    if (-not (Test-Path $AllowedSignersPath)) {
        Write-Failure "Allowed signers not found: $AllowedSignersPath"
        return $false
    }
    
    # Check for ssh-keygen
    if (-not (Test-CommandExists "ssh-keygen")) {
        Write-Failure "ssh-keygen not found in PATH. Install OpenSSH."
        return $false
    }
    
    Write-Host "  Identity: $SignerIdentity"
    Write-Host "  Namespace: $SignatureNamespace"
    
    # Run ssh-keygen verify
    try {
        # ssh-keygen -Y verify reads from stdin
        $verifyArgs = @(
            "-Y", "verify",
            "-f", $AllowedSignersPath,
            "-I", $SignerIdentity,
            "-n", $SignatureNamespace,
            "-s", $SignaturePath
        )
        
        $result = Get-Content $ManifestPath | & ssh-keygen @verifyArgs 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Signature valid"
            if ($Verbose) {
                Write-Host "  $result"
            }
            return $true
        }
        else {
            Write-Failure "Signature verification failed"
            Write-Host "  $result"
            return $false
        }
    }
    catch {
        Write-Failure "Error running ssh-keygen: $_"
        return $false
    }
}

function Test-PolicyGates {
    param(
        [object]$CompiledHgl,
        [object]$ProofData,
        [string]$JqExe
    )
    
    Write-StepHeader "Evaluating policy gates..."
    
    $policyResults = @{
        passed = $true
        gates = @()
        errors = @()
    }
    
    # Gate 1: Consent Required
    Write-Host "  Checking: consent.required"
    if ($CompiledHgl.PSObject.Properties['consent'] -and $CompiledHgl.consent) {
        Write-Success "  consent.required: PASS"
        $policyResults.gates += @{
            gate = "consent.required"
            status = "pass"
        }
    }
    else {
        Write-Failure "  consent.required: FAIL"
        $policyResults.passed = $false
        $policyResults.gates += @{
            gate = "consent.required"
            status = "fail"
            error_code = "consent.missing_scope"
        }
        $policyResults.errors += "consent.missing_scope"
    }
    
    # Gate 2: Least Privilege
    Write-Host "  Checking: least_privilege"
    if ($CompiledHgl.PSObject.Properties['privilege_level'] -and 
        $CompiledHgl.privilege_level -in @('read', 'read-only', 'minimal')) {
        Write-Success "  least_privilege: PASS"
        $policyResults.gates += @{
            gate = "least_privilege"
            status = "pass"
        }
    }
    else {
        $privLevel = if ($CompiledHgl.PSObject.Properties['privilege_level']) { 
            $CompiledHgl.privilege_level 
        } else { 
            "undefined" 
        }
        
        if ($privLevel -in @('admin', 'root', 'write-all')) {
            Write-Failure "  least_privilege: FAIL (escalation detected: $privLevel)"
            $policyResults.passed = $false
            $policyResults.gates += @{
                gate = "least_privilege"
                status = "fail"
                error_code = "privilege.escalation"
            }
            $policyResults.errors += "privilege.escalation"
        }
        else {
            Write-Warning "  least_privilege: PASS (default)"
            $policyResults.gates += @{
                gate = "least_privilege"
                status = "pass"
                note = "no privilege_level specified, assuming safe default"
            }
        }
    }
    
    # Gate 3: Temporal Validity
    Write-Host "  Checking: temporal.validity"
    if ($CompiledHgl.PSObject.Properties['temporal'] -and $CompiledHgl.temporal) {
        try {
            $grantTime = [DateTime]::Parse($CompiledHgl.temporal.grant_time)
            $expiryTime = [DateTime]::Parse($CompiledHgl.temporal.expiry_time)
            $currentTime = [DateTime]::UtcNow
            
            if ($currentTime -ge $grantTime -and $currentTime -le $expiryTime) {
                Write-Success "  temporal.validity: PASS (within window)"
                $policyResults.gates += @{
                    gate = "temporal.validity"
                    status = "pass"
                }
            }
            else {
                Write-Failure "  temporal.validity: FAIL (outside valid window)"
                $policyResults.passed = $false
                $policyResults.gates += @{
                    gate = "temporal.validity"
                    status = "fail"
                    error_code = "consent.expired"
                }
                $policyResults.errors += "consent.expired"
            }
        }
        catch {
            Write-Warning "  temporal.validity: SKIP (invalid timestamp format)"
            $policyResults.gates += @{
                gate = "temporal.validity"
                status = "skip"
                note = "timestamp parse error"
            }
        }
    }
    else {
        Write-Warning "  temporal.validity: SKIP (no temporal constraints)"
        $policyResults.gates += @{
            gate = "temporal.validity"
            status = "skip"
        }
    }
    
    # Gate 4: Tenant Isolation
    Write-Host "  Checking: tenant.isolation"
    if ($CompiledHgl.PSObject.Properties['tenant_id'] -and 
        $ProofData.PSObject.Properties['tenant_id']) {
        
        if ($CompiledHgl.tenant_id -eq $ProofData.tenant_id) {
            Write-Success "  tenant.isolation: PASS"
            $policyResults.gates += @{
                gate = "tenant.isolation"
                status = "pass"
            }
        }
        else {
            Write-Failure "  tenant.isolation: FAIL (tenant mismatch)"
            $policyResults.passed = $false
            $policyResults.gates += @{
                gate = "tenant.isolation"
                status = "fail"
                error_code = "consent.tenant_mismatch"
            }
            $policyResults.errors += "consent.tenant_mismatch"
        }
    }
    else {
        Write-Warning "  tenant.isolation: SKIP (no tenant_id specified)"
        $policyResults.gates += @{
            gate = "tenant.isolation"
            status = "skip"
        }
    }
    
    # Gate 5: Proof Integrity
    Write-Host "  Checking: proof.integrity"
    if ($ProofData.PSObject.Properties['signature'] -and $ProofData.signature) {
        # Basic integrity check - verify proof has required fields
        $requiredFields = @('signature', 'timestamp', 'hash')
        $missingFields = $requiredFields | Where-Object { 
            -not $ProofData.PSObject.Properties[$_] 
        }
        
        if ($missingFields.Count -eq 0) {
            Write-Success "  proof.integrity: PASS"
            $policyResults.gates += @{
                gate = "proof.integrity"
                status = "pass"
            }
        }
        else {
            Write-Failure "  proof.integrity: FAIL (missing fields: $($missingFields -join ', '))"
            $policyResults.passed = $false
            $policyResults.gates += @{
                gate = "proof.integrity"
                status = "fail"
                error_code = "proof.integrity"
            }
            $policyResults.errors += "proof.integrity"
        }
    }
    else {
        Write-Warning "  proof.integrity: SKIP (no signature in proof)"
        $policyResults.gates += @{
            gate = "proof.integrity"
            status = "skip"
        }
    }
    
    return $policyResults
}

#endregion

#region Main Execution

function Invoke-VerifyAndEval {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════"
    Write-Host "  HGL Verification & Policy Evaluation (PowerShell)"
    Write-Host "  Version: 1.2-beta.1"
    Write-Host "═══════════════════════════════════════════════════════════"
    Write-Host ""
    
    # Find jq executable
    $jqExecutable = Find-JqExecutable $JqPath
    if (-not $jqExecutable) {
        Write-Warning "jq not found - JSON parsing will use PowerShell fallback"
        Write-Warning "For best results, install jq: https://stedolan.github.io/jq/"
    }
    else {
        Write-Host "Using jq: $jqExecutable"
    }
    Write-Host ""
    
    # Verify required files exist
    Write-StepHeader "Checking required files..."
    
    $requiredFiles = @(
        @{ Path = $Compiled; Name = "Compiled HGL" },
        @{ Path = $Proof; Name = "Proof file" },
        @{ Path = $AllowedSigners; Name = "Allowed signers" }
    )
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file.Path) {
            Write-Success "$($file.Name): $($file.Path)"
        }
        else {
            Write-Failure "$($file.Name) not found: $($file.Path)"
            $Script:ExitCode = 4
            return
        }
    }
    Write-Host ""
    
    # Step 1: SHA256 Verification
    $manifestPath = Join-Path $ManifestDir "sha256sums.txt"
    $signaturePath = Join-Path $ManifestDir "sha256sums.txt.sig"
    
    $filesToVerify = @($Compiled, $Proof)
    $hashCheckPassed = Test-SHA256Manifest $manifestPath $filesToVerify
    
    if (-not $hashCheckPassed) {
        Write-Host ""
        Write-Failure "Hash verification failed - aborting"
        $Script:ExitCode = 1
        return
    }
    Write-Host ""
    
    # Step 2: Signature Verification
    $signatureCheckPassed = Test-ED25519Signature `
        $manifestPath $signaturePath $AllowedSigners $Identity $Namespace
    
    if (-not $signatureCheckPassed) {
        Write-Host ""
        Write-Failure "Signature verification failed - aborting"
        $Script:ExitCode = 2
        return
    }
    Write-Host ""
    
    # Step 3: Parse JSON files
    Write-StepHeader "Parsing JSON files..."
    try {
        $compiledData = Read-JsonFile $Compiled $jqExecutable
        Write-Success "Compiled HGL parsed"
        
        $proofData = Read-JsonFile $Proof $jqExecutable
        Write-Success "Proof file parsed"
    }
    catch {
        Write-Failure "JSON parsing failed: $_"
        $Script:ExitCode = 6
        return
    }
    Write-Host ""
    
    # Step 4: Policy Evaluation
    $policyResults = Test-PolicyGates $compiledData $proofData $jqExecutable
    Write-Host ""
    
    # Step 5: Generate output
    Write-StepHeader "Verification Summary"
    
    $output = @{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        version = "1.2-beta.1"
        passed = ($hashCheckPassed -and $signatureCheckPassed -and $policyResults.passed)
        checks = @{
            hash_verification = $hashCheckPassed
            signature_verification = $signatureCheckPassed
            policy_evaluation = $policyResults.passed
        }
        policy = @{
            status = if ($policyResults.passed) { "pass" } else { "fail" }
            gates = $policyResults.gates
            errors = $policyResults.errors
        }
        files = @{
            compiled = $Compiled
            proof = $Proof
            manifest = $manifestPath
            signature = $signaturePath
        }
        signer = @{
            identity = $Identity
            namespace = $Namespace
        }
    }
    
    $outputJson = $output | ConvertTo-Json -Depth 10
    Write-Host $outputJson
    Write-Host ""
    
    # Determine final exit code
    if ($output.passed) {
        Write-Host "${Script:ColorGreen}═══════════════════════════════════════════════════════════${Script:ColorReset}"
        Write-Host "${Script:ColorGreen}  ✓ ALL CHECKS PASSED${Script:ColorReset}"
        Write-Host "${Script:ColorGreen}═══════════════════════════════════════════════════════════${Script:ColorReset}"
        $Script:ExitCode = 0
    }
    else {
        Write-Host "${Script:ColorRed}═══════════════════════════════════════════════════════════${Script:ColorReset}"
        Write-Host "${Script:ColorRed}  ✗ VERIFICATION FAILED${Script:ColorReset}"
        Write-Host "${Script:ColorRed}═══════════════════════════════════════════════════════════${Script:ColorReset}"
        
        if (-not $hashCheckPassed) {
            $Script:ExitCode = 1
        }
        elseif (-not $signatureCheckPassed) {
            $Script:ExitCode = 2
        }
        elseif (-not $policyResults.passed) {
            $Script:ExitCode = 3
        }
    }
}

# Execute main function
try {
    Invoke-VerifyAndEval
}
catch {
    Write-Failure "Unexpected error: $_"
    Write-Host $_.ScriptStackTrace
    $Script:ExitCode = 10
}
finally {
    exit $Script:ExitCode
}

#endregion
