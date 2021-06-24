#!/bin/bash

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
echo "####################################################"
echo "#Listando todos os containers com interfaces ativas#"
echo "####################################################"
echo ""
list_and_show_all_interfaces
echo ""

function list_uniq_interfaces(){
for interfaces in $(list_all_interfaces | sort | uniq);do echo $interfaces;done
}

for unused_interfaces in $(list_uniq_interfaces);do orphan_interfaces="$orphan_interfaces|$unused_interfaces";done
list_only_used_interfaces=`echo $orphan_interfaces | sed 's/|/''/'`

ifconfig | grep veth | cut -f1 -d':'| egrep -v "$list_only_used_interfaces" >>/dev/null

if [ $? -ne 0 ];then
        echo "#####################################################################"    
        echo "#Não existem interfaces orfãs para serem deletadas, saindo do script#"
        echo "#####################################################################" 
        exit 10
else
        echo "###############################################################################################"
        echo "#O sistema irá deletar as seguintes interfaces que não estão sendo usadas por nenhum container#"
        echo "###############################################################################################"
        echo ""

        ifconfig | grep veth | cut -f1 -d':'| egrep -v "$list_only_used_interfaces"

        for delete_interface in $(ifconfig | grep veth | cut -f1 -d':'| egrep -v "$list_only_used_interfaces");do ip link set $delete_interface down && ip link delete $delete_interface;done

fi
