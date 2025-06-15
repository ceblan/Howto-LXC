#!/usr/bin/env bash


print_help (){
	echo "Uso: "
	echo "  -l pg_nodeX (donde X está [1 2 3])"
	echo "  -a (esto arranca los tres nodos configurados)"
	echo "bye!"
	exit 1
}

PWD=$(pwd)
ansible_dir=${PWD}/../ansible
nodos=("pg-node1" "pg-node2" "pg-node3")

crea_nodo (){

	echo "Creando nodo: $node en $(pwd)"
	ansible-playbook -i inventory.ini tasks/create-lxc-pg-node.yml --extra-vars "DEST=${node}"
	ansible-playbook -i inventory.ini tasks/install-packages-pg-node.yml -l ${node}
	ansible-playbook -i inventory.ini tasks/01-prepara_pg_node.yml -l ${node}
	ansible-playbook -i inventory.ini tasks/02-configura-patroni.yml -l ${node}
	ansible-playbook -i inventory.ini tasks/03-configura-docker-compose.yml -l ${node}
	echo "Nodo: $node Creado con éxito"
	cd -
}


valida_nodo (){
	cd ${ansible_dir}
	grep -q -E "\<${node}\>" inventory.ini
	if [ $? -eq 0 ]; then
		crea_nodo
	else
		echo "ERROR: parece que ${node} no es un nodo valido!!!"
		print_help
	fi
}

if [ "$#" -lt 1 ] || [[ "$1" != -* ]]; then
  echo "Error: Debes proporcionar nodo/s a instalar."
  print_help
  exit 1 # Salir del script con un código de error (convencionalmente, 1 indica error)
 else
	while getopts l:ah flag
	do
		case "${flag}" in
			a)
				for node in "${nodos[@]}"; do
					valida_nodo
				done
				exit 0
				;;
			l)
				node=${OPTARG}
				valida_nodo
				exit 0
				;;
			h)
				print_help
				;;
			*)
				echo "Unknown parameter"
				print_help
				;;
		esac
	done
fi





# if [ "$#" -lt 1 ]; then
#   echo "Error: Debes proporcionar qué nodo/s arrancar."
#   print_help
#   exit 1 # Salir del script con un código de error (convencionalmente, 1 indica error)
# else
# 	echo "por aquí"
# 	get_params
# fi
