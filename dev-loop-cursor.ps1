param(
  [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
  [string[]]$Items
)

# Requires: cursor-agent on PATH (install via: npm install -g cursor-agent)
# Requires: CURSOR_API_KEY env var set

if (-not $env:CURSOR_API_KEY) {
  Write-Host "ERROR: CURSOR_API_KEY not set. Export it before running." -ForegroundColor Red
  exit 1
}

foreach ($item in $Items) {
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host "Cycle for: $item" -ForegroundColor Cyan
  Write-Host "==========================================" -ForegroundColor Cyan

  Write-Host "`n--- Step 1: Create Story ---" -ForegroundColor Yellow
  cursor-agent -p --force --output-format text "Create the story $item - follow the gds-create-story workflow" 2>&1 | Tee-Object "_bmad-output/logs/$item-step1.log"

  Write-Host "`n--- Step 2: Dev Story ---" -ForegroundColor Yellow
  cursor-agent -p --force --output-format text "Implement the story $item - follow the gds-dev-story workflow" 2>&1 | Tee-Object "_bmad-output/logs/$item-step2.log"

  Write-Host "`n--- Step 3: Analyze ---" -ForegroundColor Yellow
  $analyzeResult = flutter analyze 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter analyze FAILED for $item — stopping loop." -ForegroundColor Red
    Write-Host $analyzeResult
    exit 1
  }

  Write-Host "`n--- Step 4: Code Review ---" -ForegroundColor Yellow
  cursor-agent -p --force --output-format text "Run a code review on the latest changes for story $item - follow the gds-code-review workflow" 2>&1 | Tee-Object "_bmad-output/logs/$item-step3.log"

  git add -A
  git commit -m "story $item`: implementation + review"

  Write-Host "`n[$(Get-Date)] Cycle complete for: $item" -ForegroundColor Green
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "All items processed." -ForegroundColor Cyan
