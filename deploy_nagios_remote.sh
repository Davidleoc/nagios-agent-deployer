#!/bin/bash

lista_servidores="$2"
DMZ="$3"

# Linha que deve existir no arquivo common.cfg
LINE3="command[check_time_sync]=/usr/local/nagios/libexec/check_time_sync"
CONFIG_FILE="/usr/local/nagios/etc/nrpe/common.cfg"

while read -r servername
do
    if [ "$DMZ" == "DMZ" ]; then
        user="LBVDC\\srvlinuxmgmt"
        username="srvlinuxmgmt"
        user_host="$user@$servername"
        remote_check_path="/usr/local/nagios/libexec/meu_check_time_sync"
        local_check_file="$1/nagios/meu_check_time_sync"
        local_deploy_file="$1/nagios/deploy.sh"
        remote_deploy_path="/home/LBVDC/srvlinuxmgmt/deploy.sh"
    else
        user="srvlinuxmgmt"
        username="srvlinuxmgmt"
        user_host="$user@$servername"
        remote_check_path="/usr/local/nagios/libexec/check_time_sync"
        local_check_file="$1/nagios/check_time_sync"
        local_deploy_file="$1/nagios/deploy.sh"
        remote_deploy_path="/home/LBVDC/srvlinuxmgmt/deploy.sh"
    fi

    if ssh -qno StrictHostKeyChecking=no -tt "$user_host" sudo -n true 2>/dev/null; then
        echo "-------------------------------------------------------------------------------------------------"
        echo "                                                                                               "

        # Função para verificar e copiar arquivo, com ou sem sudo
        check_and_copy() {
            local local_file=$1
            local remote_file=$2

            if [ ! -f "$local_file" ]; then
                echo -e "\e[31mERRO: Arquivo local '$local_file' não existe.\e[0m"
                return 1
            fi

            local local_sum remote_sum remote_exists
            local_sum=$(sha256sum "$local_file" | awk '{print $1}')

            [[ "$remote_file" == /usr/local/* ]] && use_sudo="sudo" || use_sudo=""

            remote_exists=$(ssh -qno StrictHostKeyChecking=no -tt "$user_host" "$use_sudo test -f '$remote_file' && echo yes || echo no" | tr -d '\r')

            if [ "$remote_exists" != "yes" ]; then
                rsync -av --progress -e ssh --rsync-path="$use_sudo rsync" "$local_file" "$user_host":"$remote_file" &>/dev/null
                echo -e "\e[32mINFO: O arquivo '$remote_file' não existia no servidor $servername e foi copiado.\e[0m"
            else
                remote_sum=$(ssh -qno StrictHostKeyChecking=no -tt "$user_host" "$use_sudo sha256sum '$remote_file' 2>/dev/null || echo none" | awk '{print $1}' | tr -d '\r')

                if [ "$remote_sum" == "$local_sum" ]; then
                    echo -e "\e[33mINFO: O arquivo '$remote_file' já está atualizado no servidor $servername. Nenhuma cópia foi feita.\e[0m"
                else
                    rsync -av --progress -e ssh --rsync-path="$use_sudo rsync" "$local_file" "$user_host":"$remote_file" &>/dev/null
                    echo -e "\e[32mINFO: O arquivo '$remote_file' estava desatualizado no servidor $servername e foi copiado.\e[0m"
                fi
            fi
        }

        # Função para verificar se a linha do check_time_sync existe no common.cfg
        check_nrpe_config_line() {
            ssh -qno StrictHostKeyChecking=no -tt "$user_host" "sudo grep -Fxq \"$LINE3\" \"$CONFIG_FILE\"" 2>/dev/null
            return $?
        }

        # Copiar arquivos necessários
        check_and_copy "$local_check_file" "$remote_check_path"
        check_and_copy "$local_deploy_file" "$remote_deploy_path"

        # Verificar se a configuração do check_time_sync já está no common.cfg
        if check_nrpe_config_line; then
            echo -e "\e[33mINFO: As linhas já existem no arquivo common.cfg do servidor $servername. Nada foi alterado.\e[0m"
        else
            output=$(ssh -qno StrictHostKeyChecking=no -tt "$user_host" "sh '$remote_deploy_path'" 2>/dev/null)
            if echo "$output" | grep -q "Linhas adicionadas com sucesso"; then
                echo -e "\e[32mINFO: As linhas foram adicionadas ao arquivo common.cfg do servidor $servername.\e[0m"
            else
                echo -e "\e[31mERRO: Não foi possível confirmar se as linhas foram adicionadas ao servidor $servername.\e[0m"
            fi
        fi

        echo -e "\e[32mINFO: O script foi feito com sucesso no servidor: $servername\e[0m"
    else
        echo -e "\e[31mO usuario nao possui acesso no servidor: $servername\e[0m"
        echo "-------------------------------------------------------------------------------------------------"
        echo "                                                                                               "
    fi
done < "$lista_servidores"
