#!/bin/bash
#Argumentos
#set -x
#set -e
lista_servidores="$2"
TIPO="$3"
PATH_NAGIOS="/usr/local/nagios/libexec/"

while read -r servername;
do
    if [[ "$TIPO" == "DMZ" || "$TIPO" == "ASTERISK" ]]; then
        #user="LBVDC\\srvlinuxmgmt"
        user="srvlinuxmgmt"
        username="srvlinuxmgmt"
        user_host="$user@$servername"
        remote_check="/usr/local/nagios/libexec/check_time_sync"
        ARQUIVO1="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/check_time_sync"
        ARQUIVO2="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/common_time_sync.sh"
        remote_deploy="/home/DMZ/srvlinuxmgmt/common_time_sync.sh"
        PASTA1="/home/DMZ/srvlinuxmgmt/"
        REMOVE_ARQUIVO="/home/DMZ/srvlinuxmgmt/common_time_sync.sh"

    elif [ "$TIPO" == "AWS" ]; then
        user="srvlinuxmgmt"
        username="srvlinuxmgmt"
        user_host="$user@$servername"
        remote_check="/usr/local/nagios/libexec/check_time_sync"
        ARQUIVO1="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/check_time_sync"
        ARQUIVO2="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/common_time_sync.sh"
        remote_deploy="/home/srvlinuxmgmt/common_time_sync.sh"
        PASTA1="/home/srvlinuxmgmt/"
        REMOVE_ARQUIVO="/home/srvlinuxmgmt/common_time_sync.sh"

    elif [ "$TIPO" == "AZURE" ]; then
        user="srvlinuxmgmt"
        username="srvlinuxmgmt"
        user_host="$user@$servername"
        remote_check="/usr/local/nagios/libexec/check_time_sync"
        ARQUIVO1="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/check_time_sync"
        ARQUIVO2="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/common_time_sync.sh"
        remote_deploy="/home/srvlinuxmgmt/common_time_sync.sh"
        PASTA1="/home/srvlinuxmgmt/"
        REMOVE_ARQUIVO="/home/srvlinuxmgmt/common_time_sync.sh"

    else
        user="srvlinuxmgmt"
        username="srvlinuxmgmt"
        user_host="$user@$servername"
        remote_check="/usr/local/nagios/libexec/check_time_sync"
        ARQUIVO1="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/check_time_sync"
        ARQUIVO2="/home/LBVDC/srvlinuxmgmt/servidores-linux/scripts/arquivos/timesync/common_time_sync.sh"
        remote_deploy="/home/LBVDC/srvlinuxmgmt/common_time_sync.sh"
        PASTA1="/home/LBVDC/srvlinuxmgmt/"
        REMOVE_ARQUIVO="/home/LBVDC/srvlinuxmgmt/common_time_sync.sh"
    fi

#Criando a conexão ssh
 if ssh -qno StrictHostKeyChecking=no -tt "$user_host" sudo -n true < /dev/null 2>/dev/null ; then
                        echo -e "\e[32m-------------------------------------------------------------------------------------------------\e[0m"
                        echo

#Fazendo copias de arquivos
        if ssh $user_host "[ -f $remote_deploy ]" < /dev/null 2>/dev/null; then
                 #ssh $user_host "sudo rm /usr/local/nagios/libexec/check_time_sync" < /dev/null 2>/dev/null

                        echo -e "\e[32m✓\e[0m O "$remote_deploy" ja existe no servidor "$servername". Nada foi alterado."
        else
                        echo "Enviando "$ARQUIVO2" para "$remote_deploy" no servidor "$servername"."
                        scp -q $ARQUIVO2 $user_host:$PASTA1 < /dev/null 2>/dev/null
#Checando se funcionou
                if [ $? -eq 0 ]; then
                        echo -e "\e[32m✓\e[0m Script copiado com sucesso para "$servername"."
                else
                        echo -e "\e[31m❌\e[0m Falha ao copiar o script para "$servername"."
                fi

        fi
#Executando o script no servidor destino
                ssh -qno StrictHostKeyChecking=no -tt "$user_host" "sh '$remote_deploy'" < /dev/null 2>/dev/null

        if [ $? -eq 0 ]; then
                        echo -e "\e[32m✓\e[0m O script foi executado com  sucesso no servidor "$servername"."
        else
                        echo -e "\e[31m❌\e[0m Falha ao executar o script no servidor "$servername"."
        fi
                        echo
          #      scp $ARQUIVO1 $user_host:$PATH_NAGIOS &>/dev/null
        if ssh $user_host "[ -f $ARQUIVO1 ]" < /dev/null 2>/dev/null; then
                        echo -e "\e[32✓\e[0 O "$ARQUIVO1" ja existe no servidor "$servername". Nada foi alterado."
        else
                        scp -q "$ARQUIVO1" "$user_host:/tmp/check_time_sync" < /dev/null 2>/dev/null
                        ssh "$user_host" "sudo mv /tmp/check_time_sync /usr/local/nagios/libexec/" < /dev/null 2>/dev/null
                        ssh "$user_host" "sudo chmod 755 /usr/local/nagios/libexec/" < /dev/null 2>/dev/null
                        ssh "$user_host" "sudo chown root:nagios /usr/local/nagios/libexec/" < /dev/null 2>/dev/null

                if [ $? -eq 0 ]; then
                        echo -e "\e[32m✓\e[0m Arqivo "$ARQUIVO1" foi copiado com sucesso para "$servername"."
                else
                        echo -e "\e[31m❌\e[0m Falha ao copiar o arquivo "$ARQUIVO1"  para "$servername"."
                fi
        fi
#Removendo o script deploy.sh
        if ssh $user_host "[ -f $remote_deploy ]" < /dev/null 2>/dev/null; then
                ssh $user_host  "sudo rm -f $REMOVE_ARQUIVO" < /dev/null 2>/dev/null
        fi
                        echo
 fi
done < "$lista_servidores"
