# Local deployment via multipass and a multinode microk8s cluster
## Create VmM nodes
```bash
# download multipass
snap install multipass
# download ldx
snap install ldx
sudo ldx init
multipass set local.driver=lxd
multipass launch --name master -m 4G -d 20GB --network -ldxbr0
multipass launch --name worker1 -m 4G -d 20GB
multipass launch --name worker2 -m 4G -d 20GB
```
## Install microk8s on the multipass nodes
```bash

multipass shell master

sudo snap install microk8s --classic --channel=1.19/stable && sudo usermod -a -G microk8s $USER && sudo chown -f -R $USER ~/.kube && exit

multipass mount master /path/to/your/jambones/infra/repo
multipass shell master

microk8s enable dns storage

sudo microk8s add-node
# this command will give you something like this:
# Join node with: microk8s join 192.168.64.4:25000/IfrgUOBCMGxZyAcRgEXXLONcwMKWpstO
# you need to repeat this for each worker node

```
## Install microk8s on worker nodes

```bash

multipass shell worker1
sudo snap install microk8s --classic --channel=1.19/stable
sudo microk8s join 192.168.64.4:25000/IfrgUOBCMGxZyAcRgEXXLONcwMKWpstO
# repeat these steps for worker2 

```
## Add labels to worker nodes and deploy
```bash
multipass shell master
kubectl label nodes worker1 voip-environment=edge &&
kubectl label nodes worker2 voip-environment=edge &&
# we need to have 2 different groups so no ports are blocked by the other deployment...
kubectl taint nodes worker1 voip-edge=true:NoSchedule
kubectl taint nodes worker2 media-edge=true:NoSchedule 
 
# create registry token
kubectl create secret docker-registry cognigy-registry-token \
    --docker-server=cognigydevelopment.azurecr.io \
    --docker-username=<username> \
    --docker-password='<token>'

## change the external IP for traefik to match your network
## traefik-service.yaml
## you can get the proper IP by executing 

microk8s add-node 

## you should see 2 different IPs, take the one from the buttom as your clusters public external IP

cd /path/to/your/mount from steps before

kubectl apply -k .

# for connecting via Lens, get the k8s config via:
microk8s config

exit

## now add this external IP to /etc/hosts
sudo nano /etc/hosts

<EXTERNAL_IP> ui api
```

// todo setting up the SIP connection via web portal + how to test if everything is working as expected


Useful links
https://multipass.run/docs/additional-networks
https://www.techrepublic.com/article/how-to-share-data-between-host-and-vm-with-multipass/
https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
https://www.jambonz.org/docs/open-source/self-host/
https://github.com/drachtio/drachtio-server/blob/main/entrypoint.sh
https://github.com/jambonz/jambonz-infrastructure/blob/Add-kubernetes-deployment/kubernetes/drachtio-sbc/drachtio-sbc-deployment.yaml
https://github.com/davehorton/drachtio-ipv6proxy
https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
https://pancho.dev/posts/multipass-microk8s-cluster/
