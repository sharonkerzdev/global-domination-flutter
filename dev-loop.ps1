param(
  [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
  [string[]]$Items
)

foreach ($item in $Items) {
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host "Cycle for: $item" -ForegroundColor Cyan
  Write-Host "==========================================" -ForegroundColor Cyan

  Write-Host "`n--- Step 1: Create Story ---" -ForegroundColor Yellow
  claude --dangerously-skip-permissions -p "/gds-create-story $item" --model claude-opus-4-7 --verbose

  Write-Host "`n--- Step 2: Dev Story ---" -ForegroundColor Yellow
  claude --dangerously-skip-permissions -p "/gds-dev-story $item" --model claude-sonnet-4-6 --verbose

  Write-Host "`n--- Step 3: Code Review ---" -ForegroundColor Yellow
  claude --dangerously-skip-permissions -p "/gds-code-review $item" --model claude-opus-4-7 --verbose

  Write-Host "`n[$(Get-Date)] Cycle complete for: $item" -ForegroundColor Green
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "All items processed." -ForegroundColor Cyan
