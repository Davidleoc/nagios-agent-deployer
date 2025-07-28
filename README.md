# Nagios Agent Deployer

Este script realiza a cópia e configuração automática de plugins Nagios nos servidores de monitoramento remoto.

## Funcionalidades

- Verifica e atualiza o plugin `check_time_sync` via `rsync`.
- Verifica se a configuração no arquivo `common.cfg` já existe.
- Executa o script `deploy.sh` remotamente apenas se necessário.
- Suporte a servidores com e sem domínio.
- Suporte a execuções paralelas com `xargs -P`.

## Requisitos

Para o correto funcionamento do script, é necessário ter disponível:

- **Uma lista de servidores** para deploy, por exemplo:  
  `servidores/meu_teste.txt` — contendo um servidor por linha.

- **O script `deploy.sh`** com o seguinte conteúdo, que será copiado e executado remotamente para atualizar o arquivo `common.cfg`:

```bash
CONFIG_FILE="/usr/local/nagios/etc/nrpe/common.cfg"
LINE1=""
LINE2="### TIMESYNC ###"
LINE3="command[check_time_sync]=/usr/local/nagios/libexec/check_time_sync"

# Verifica se a linha 3 já existe
if ! sudo grep -Fxq "$LINE3" "$CONFIG_FILE"; then
    echo "$LINE1"    | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "$LINE2"    | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "$LINE3"    | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "Linhas adicionadas com sucesso."
else
    echo "As linhas já existem. Nada foi alterado."
fi
```
- Se a linha do comando já existe, não altera nada e informa que está tudo ok.

- Caso contrário, insere a configuração necessária para que o NRPE saiba executar o plugin `check_time_sync`

- **E por fim o Plugin**
`check_time_sinc`

```bash

#!/bin/bash

EXIT_CODE=0

# Função para checar status de um serviço
check_service() {
    local svc=$1
    if systemctl is-active --quiet "$svc"; then
        echo "OK: Servico '$svc' esta ativo."
        return 0
    else
        echo "WARNING: Servico '$svc' nao esta ativo."
        return 1
    fi
}

# Detecta qual serviço NTP está ATIVO
NTP_SERVICE=""
if systemctl is-active --quiet systemd-timesyncd; then
    NTP_SERVICE="systemd-timesyncd"
elif systemctl is-active --quiet ntp; then
    NTP_SERVICE="ntp"
elif systemctl is-active --quiet chronyd; then
    NTP_SERVICE="chronyd"
else
    echo "CRITICAL: Nenhum servico NTP reconhecido encontrado."
    exit 2
fi

# Verifica se o serviço detectado está ativo
if ! check_service "$NTP_SERVICE"; then
    EXIT_CODE=1
fi

# Verifica sincronização (funciona com systemd)
SYNC_STATUS=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
if [ "$SYNC_STATUS" = "yes" ]; then
    echo "OK: Relogio do sistema esta sincronizado."
else
    echo "CRITICAL: Relogio do sistema NAO esta sincronizado."
    EXIT_CODE=2
fi

# Coleta informações se for systemd-timesyncd
if [ "$NTP_SERVICE" = "systemd-timesyncd" ]; then
    TIMESYNC_DATA=$(timedatectl show-timesync --all 2>/dev/null)

    SERVER_NAME=$(echo "$TIMESYNC_DATA" | grep '^ServerName=' | cut -d= -f2)
    SERVER_ADDRESS=$(echo "$TIMESYNC_DATA" | grep '^ServerAddress=' | cut -d= -f2)

    if [ -n "$SERVER_NAME" ] || [ -n "$SERVER_ADDRESS" ]; then
        echo "INFO: Sincronizado com: $SERVER_NAME ($SERVER_ADDRESS)"
    else
        echo "WARNING: Nenhum servidor NTP identificado."
        [ $EXIT_CODE -lt 1 ] && EXIT_CODE=1
    fi
else
    echo "INFO: Serviço NTP em uso: $NTP_SERVICE (sem dados adicionais via timedatectl)"
fi

exit $EXIT_CODE

```
- Detecta qual serviço NTP está ativo (systemd-timesyncd, ntp, chronyd)

- Verifica se o serviço está rodando

- Confirma se o relógio do sistema está sincronizado

- Fornece informações adicionais caso esteja usando systemd-timesyncd

- Retorna códigos e mensagens adequadas para o Nagios interpretar

## Uso

```bash
./deploy_nagios_remote.sh <diretório_com_arquivos> <arquivo_de_lista_de_servidores> [DMZ]
