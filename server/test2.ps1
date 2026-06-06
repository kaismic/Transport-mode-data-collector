$api = "https://pmegv0abk8.execute-api.ap-southeast-2.amazonaws.com/Prod"

$confirmBody = @{
  session_id = "11111111-1111-4111-8111-111111111113"
  uploaded_at_ms = 1710000070000
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$api/sessions/confirm-upload" `
  -ContentType "application/json" `
  -Body $confirmBody