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
  cursor-agent --dangerously-skip-permissions -p "/gds-create-story $item" --model "Gemini 3.1 Pro" --verbose

  Write-Host "`n--- Step 2: Dev Story ---" -ForegroundColor Yellow
  cursor-agent --dangerously-skip-permissions -p "/gds-dev-story $item" --model "Composer 2" --verbose

  Write-Host "`n--- Step 3: Code Review ---" -ForegroundColor Yellow
  cursor-agent --dangerously-skip-permissions -p "/gds-code-review $item" --model "Gemini 3.1 Pro" --verbose

  Write-Host "`n[$(Get-Date)] Cycle complete for: $item" -ForegroundColor Green
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "All items processed." -ForegroundColor Cyan
