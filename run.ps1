# Lê as configurações do arquivo config.json
$config = Get-Content -Path .\config.json | ConvertFrom-Json

# Configurações de acesso AWS
$aws_access_key_id = $config.aws_access_key_id
$aws_secret_access_key = $config.aws_secret_access_key

# Configurações da pasta local e bucket S3
$local_folder = $config.local_folder
$s3_bucket = $config.s3_bucket

# Configurações de login do GLPI
$GLPI_API_URL = '$GLPI_API_URr/apirest.php'
$GLPI_USERNAME = $config.glpi_username
$GLPI_PASSWORD = $config.glpi_password

# Faz login no GLPI e obtém o token de sessão
$GLPI_API_URL = $config.glpi_api_url
$response = Invoke-RestMethod -Uri "$GLPI_API_URL/initSession" -Method Post -ContentType "application/json" -Body ('{"login": "' + $GLPI_USERNAME + '", "password": "' + $GLPI_PASSWORD + '"}')
$GLPI_SESSION_TOKEN = $response.session_token


# Executa o comando AWS S3 Sync para sincronizar a pasta local com o bucket S3
try {
    aws s3 sync "$local_folder" "s3://$s3_bucket" --delete --region us-east-1 --profile default
    Write-Host "Sincronização da pasta local $local_folder com o bucket S3 $s3_bucket concluída com sucesso."
}
catch {
    # Abre um chamado no GLPI em caso de erro
    $GLPI_APP_TOKEN = $config.glpi_app_token
    $GLPI_USER_TOKEN = $config.glpi_user_token
    
    $description = "Ocorreu um erro ao sincronizar a pasta local $local_folder com o bucket S3 $s3_bucket\: $_"
    $data = @{
        input = @{
            name = 'Erro na sincronização do S3'
            content = $description
            urgency = 3
            impact = 3
            priority = 3
            itilcategories_id = 15
            type = 2
            entities_id = $config.entities_id
        }
    }

    $headers = @{
        'Session-Token' = $GLPI_SESSION_TOKEN
        'App-Token' = $GLPI_APP_TOKEN
        'User-Token' = $GLPI_USER_TOKEN
    }

    $response = Invoke-RestMethod -Uri "$GLPI_API_URL/Ticket" -Method Post -ContentType "application/json" -Body ($data | ConvertTo-Json) -Headers $headers
    if ($response -contains 'id') {
        Write-Host "Erro ao abrir chamado no GLPI: $($response.text)"
    }
}
