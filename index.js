const fs = require('fs');
const axios = require('axios');

// Lê as configurações do arquivo config.json
const configFile = fs.readFileSync('./config.json', 'utf8');
const config = JSON.parse(configFile);

// Configurações da pasta local e bucket S3
const localFolder = config.local_folder;
const s3Bucket = config.s3_bucket;

// Configurações de login do GLPI
const glpiUsername = config.glpi_username;
const glpiPassword = config.glpi_password;

// Faz login no GLPI e obtém o token de sessão
const glpiApiUrl = config.glpi_api_url;
axios.post(`${glpiApiUrl}/initSession`, { login: glpiUsername, password: glpiPassword })
  .then((response) => {
    const glpiSessionToken = response.data.session_token;

    // Executa o comando AWS S3 Sync para sincronizar a pasta local com o bucket S3
    const exec = require('child_process').exec;
    const cmd = `aws s3 sync ${localFolder} s3://${s3Bucket} --region us-east-1 --storage-class GLACIER_IR`;

    exec(cmd, (error, stdout, stderr) => {
      if (error) {
        // Abre um chamado no GLPI em caso de erro
        const glpiAppToken = config.glpi_app_token;
        const glpiUserToken = config.glpi_user_token;

        const description = `Ocorreu um erro ao sincronizar a pasta local ${localFolder} com o bucket S3 ${s3Bucket}: ${error}`;
        const data = {
          input: {
            name: 'Erro na sincronização do S3',
            content: description,
            urgency: 3,
            impact: 3,
            priority: 3,
            itilcategories_id: 15,
            type: 2,
            entities_id: config.entities_id,
          },
        };

        const headers = {
          'Session-Token': glpiSessionToken,
          'App-Token': glpiAppToken,
          'User-Token': glpiUserToken,
        };

        axios.post(`${glpiApiUrl}/Ticket`, data, { headers })
          .then((response) => {
            if (!response.data.id) {
              console.log(`Erro ao abrir chamado no GLPI: ${response.data.text}`);
            }
          })
          .catch((error) => {
            console.log(`Erro ao abrir chamado no GLPI: ${error}`);
          });
      } else {
        console.log(`Sincronização da pasta local ${localFolder} com o bucket S3 ${s3Bucket} concluída com sucesso.`);
      }
    });
  })
  .catch((error) => {
    console.log(`Erro ao fazer login no GLPI: ${error}`);
  });