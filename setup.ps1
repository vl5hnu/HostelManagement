# One-time project setup. Run from this folder:  .\setup.ps1
# Generates the android/ and ios/ folders around the existing lib/ code and
# adds the Firebase packages.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Flutter needs git; fall back to the copy bundled with the Flutter SDK.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $flutterBin = Split-Path (Get-Command flutter).Source
    $env:PATH = "$flutterBin\mingit\cmd;$env:PATH"
}

# Org + project name must produce com.abhishek.hostelmanagement, the app id
# registered in Firebase for both Android and iOS.
flutter create --platforms=android,ios --org com.abhishek --project-name hostelmanagement .
if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }

flutter pub add firebase_core firebase_auth cloud_firestore
if ($LASTEXITCODE -ne 0) { throw 'flutter pub add failed' }

# The generated counter-app test does not match this app.
if (Test-Path test\widget_test.dart) { Remove-Item test\widget_test.dart }

Write-Host ''
Write-Host 'Done. Next: connect Firebase (see README.md, step 2).'
