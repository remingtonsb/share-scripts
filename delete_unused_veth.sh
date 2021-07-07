#!/bin/bash



### Functions ###

function list_all_interfaces(){
for container in $(docker ps --format '{{.Names}}'); do
     iflink=`docker exec -it $container bash -c 'cat /sys/class/net/eth*/iflink'`
    for net in $iflink;do
        net=`echo $net|tr -d '\r'`
        veth=`grep -l $net /sys/class/net/veth*/ifindex`
        veth=`echo $veth|sed -e 's;^.*net/\(.*\)/ifindex$;\1;'`
        echo $container:$veth|sed 's/k8s_//' | cut -f2 -d':'
    done
done
}

function list_and_show_all_interfaces(){
for container in $(docker ps --format '{{.Names}}'); do
     iflink=`docker exec -it $container bash -c 'cat /sys/class/net/eth*/iflink'`
    for net in $iflink;do
        net=`echo $net|tr -d '\r'`
        veth=`grep -l $net /sys/class/net/veth*/ifindex`
        veth=`echo $veth|sed -e 's;^.*net/\(.*\)/ifindex$;\1;'`
        echo $container:$veth|sed 's/k8s_//'
    done
done
}

function list_uniq_interfaces(){
for interfaces in $(list_all_interfaces | sort | uniq);do echo $interfaces;done
}

function operations_veth(){

	TOTAL_VETHS=`ip a | grep veth | wc -l`
        TOTAL_PODS=`sudo docker ps | grep POD | wc -l`
        TOTAL_NOT_USED=`ifconfig | grep veth | cut -f1 -d':'| egrep -v "$list_only_used_interfaces" | wc -l`
        SUB_VETH=`expr $TOTAL_VETHS - $TOTAL_PODS`
        echo ""
        echo "###############################################################################################"
        echo "Informações das interfaces veth                                                               #"
        echo "###############################################################################################" 
        echo "Total veth no servidor      : "$TOTAL_VETHS
        echo "Total PODS no Servidor      : "$TOTAL_PODS
        echo "Total veth orfãs no Servidor: "$TOTAL_NOT_USED
}


function list_orphaned_interfaces(){
	for unused_interfaces in $(list_uniq_interfaces);do orphan_interfaces="$orphan_interfaces|$unused_interfaces";done
	list_only_used_interfaces=`echo $orphan_interfaces | sed 's/|/''/'`
        ifconfig | grep veth | cut -f1 -d':'| egrep -v "$list_only_used_interfaces" >>/dev/null
}

function restart_docker(){
	sudo systemctl restart docker
	
}

function delete_interfaces(){
			echo "" 
                        echo "###################################################################################################"
                        echo "#O script irá deletar as seguintes interfaces veth que não estão sendo usadas por nenhum container#"
                        echo "###################################################################################################"
                        echo "" 

                        ifconfig | grep veth | cut -f1 -d':'| egrep -v "$list_only_used_interfaces"

                        for delete_interface in $(ifconfig | grep veth | cut -f1 -d':'| egrep -v "$list_only_used_interfaces");do ip link set $delete_interface down && ip link delete $delete_interface;done
}

### Starting Script ###

echo "####################################################"
echo "#Listando todos os containers com interfaces ativas#"
echo "####################################################"
echo ""
list_and_show_all_interfaces
echo ""

list_orphaned_interfaces

if [ $? -ne 0 ];then
        echo ""
        operations_veth
	echo ""
        echo "##########################################################################"    
        echo "#Não existem interfaces veth orfãs para serem deletadas, saindo do script#"
        echo "##########################################################################"
        echo "Saindo do Script" 
        exit 10
else    
        operations_veth
        
	if [ "$TOTAL_NOT_USED" -gt "$SUB_VETH" ]; then
		echo ""
		echo "Reiniciando Docker"
                restart_docker
                if [ $? -ne 0 ];then
			echo "Problemas para reiniciar o Docker"
			exit 11
		else
			echo ""
			echo "Docker Reiniciado com Sucesso"
                        delete_interfaces
		fi
 		
	else
		delete_interfaces	

	fi
fi
