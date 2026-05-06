#!/bin/bash

# Kullavik 20260505
#Script that installs Docker and creates a container with Ansible on Fedora Linux.
#Method 2: macvlan with a dedicated IP for the container; this doesn't work because the host machine loses network connectivity entirely.

# --- KONFIGURATION ---
INTERFACE="eth0"
CONTAINER_IP="10.0.0.5"
SUBNET="10.0.0.0/24"
GATEWAY="10.0.0.1"
SSH_HOST_PORT="2222"
ROOT_PASSWORD="XXXXXXXXXX"
CONTAINER_NAME="ansible-engine"
IMAGE="quay.io/fedora/fedora:latest"
LANDING_PATH="/srv/dockercontainer/ansible"
DOCKER_REPO="https://download.docker.com/linux/fedora/docker-ce.repo"
# ----------------------

echo "--- STEG 1: INSTALLERAR DOCKER OCH BRANDVÄGG ---"
sudo dnf install -y firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=$DOCKER_REPO
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

echo "--- STEG 2: FÖRBEREDER ANSIBLE-MILJÖN ---"
sudo mkdir -p $LANDING_PATH
sudo chown -R $USER:$USER $LANDING_PATH
sudo docker rm -f $CONTAINER_NAME 2>/dev/null || true
sudo docker network rm macvlan_lan 2>/dev/null || true

# ================================================== ========
# METOD 1: MED MACVLAN INAKTIVERAD
# Ta bort # under denna rad för att aktivera Macvlan
# ================================================== ========
#echo "Kör METOD: MACVLAN ($CONTAINER_IP)"
#sudo firewall-cmd --permanent --add-service=ssh
#sudo firewall-cmd --permanent --add-interface=$INTERFACE
#sudo firewall-cmd --reload
#
##sudo docker network create -d macvlan --subnet=$SUBNET --gateway=$GATEWAY -o parent=$INTERFACE macvlan_lan
#
#sudo docker run -d \
# --name $CONTAINER_NAME \
# --restart=always \
# --privileged \
# --network macvlan_lan \
# --ip $CONTAINER_IP \
# -v $LANDING_PATH:/data \
# $IMAGE \
# /bin/bash -c "dnf install -y openssh-server ansible python3-pip && ssh-keygen -A && mkdir -p /run/sshd && echo 'root:$ROOT_PASSWORD' | chpasswd && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && /usr/sbin/sshd -D"
#
#sudo ip link add mac0 link $INTERFACE type macvlan mode bridge 2>/dev/null || true
#sudo ip addr add 10.20.20.240/24 dev mac0 2>/dev/null || true
#sudo ip link set mac0 up
#sudo ip route add $CONTAINER_IP dev mac0 2>/dev/null || true
# --- SLUT PÅ METOD 1 MACVLAN ---


## ================================================== ========
## METOD 2: UTAN MACVLAN (AKTIV)### Denna metod använder standard bridge och port-mapping
## ================================================== ========
echo "Kör METOD: UTAN MACVLAN (localhost:$SSH_HOST_PORT)"
sudo firewall-cmd --permanent --add-port=$SSH_HOST_PORT/tcp
sudo firewall-cmd --reload
sudo docker run -d \
--name $CONTAINER_NAME \
--restart=always \
--privileged \
-p $SSH_HOST_PORT:22 \
-v $LANDING_PATH:/data \
$IMAGE \
/bin/bash -c "dnf install -y openssh-server ansible python3-pip && ssh-keygen -A && mkdir -p /run/sshd && echo 'root:$ROOT_PASSWORD' | chpasswd && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && /usr/sbin/sshd -D"
# --- SLUT PÅ METOD 2 UTAN MACVLAN ---


echo "-------------------------------------------------------"
echo "INSTALLATION SLUTFÖRD!"
echo "Anslut nu via: ssh root@localhost -p $SSH_HOST_PORT"
echo "Lösenord: $ROOT_PASSWORD"
echo "Mapp på hosten: $LANDING_PATH"
echo "-------------------------------------------------------"
