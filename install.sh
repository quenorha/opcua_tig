#!/bin/bash

wget -q --spider http://google.com

if [ $? -eq 0 ]; then
    echo "Accès Internet détecté, installation Online"
	echo "Téléchargement du package Docker"
	wget https://github.com/WAGO/docker-ipk/releases/download/v1.0.4-beta/docker_20.10.5_armhf.ipk -P /tmp/

	echo "Téléchargement des fichiers de configuration"
	mkdir /root/config
	mkdir /root/certs
	wget https://raw.githubusercontent.com/quenorha/opcua_tig/main/conf/telegraf.conf -P /root/config/
	wget https://raw.githubusercontent.com/quenorha/opcua_tig/main/conf/daemon.json -P /root/config/
	wget https://raw.githubusercontent.com/quenorha/opcua_tig/main/conf/ssl.conf -P /root/config/
	echo "Installation Docker"
	opkg install -V3 /tmp/docker_20.10.5_armhf.ipk
	
	echo "Activation IP Forwarding"
	/etc/config-tools/config_routing -c general state=enabled

	echo "Arrêt Docker"
	/etc/init.d/dockerd stop
	sleep 3

	echo "Déplacement docker vers la carte SD"
	cp -r /home/docker /media/sd
	rm -r /home/docker
	cp /root/config/daemon.json /etc/docker/daemon.json

	echo "Démarrage Docker"
	/etc/init.d/dockerd start
	sleep 3

	echo "Téléchargement image Portainer"
	docker pull portainer/portainer-ce:2.6.1
	
	echo "Téléchargement image Influxdb"
	docker pull influxdb:1.8.6
	
	echo "Téléchargement image Grafana"
	docker pull grafana/grafana:8.0.0
	
	echo "Téléchargement image Telegraf"
	docker pull telegraf:1.19.1
	
	echo "Création network"
	docker network create wago

	echo "Création volumes"
	docker volume create v_portainer
	docker volume create v_grafana
	docker volume create v_influxdb

	echo "Démarrage Portainer"
	docker run -d -p 8000:8000 -p 9000:9000 --name=c_portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v v_portainer:/data portainer/portainer-ce:2.6.1


	echo "Démarrage InfluxDB"
	docker run -d -p 8086:8086 --name c_influxdb --net=wago --restart unless-stopped -v v_influxdb influxdb:1.8.6

	echo "Démarrage Grafana"
	docker run -d -p 3000:3000 --name c_grafana -e GF_PANELS_DISABLE_SANITIZE_HTML=true --net=wago --restart unless-stopped -v v_grafana grafana/grafana:8.0.0
	
	echo "Génération des clés et certificats SSL pour l'OPC UA"
	openssl genrsa -out /root/certs/key.pem 2048
	openssl req -x509 -days 365 -new -out /root/certs/certificate.pem -key /root/certs/key.pem -config /root/config/ssl.conf


	echo "Démarrage Telegraf"
	docker run --restart=unless-stopped --net=wago --name=c_telegraf -v /root/certs/:/etc/telegraf/certs/ -v /root/config/telegraf.conf:/etc/telegraf/telegraf.conf:ro telegraf:1.19.1

	
else
    echo "Aucun accès Internet détecté, vérifier les paramètres DNS et Gateway"
fi

