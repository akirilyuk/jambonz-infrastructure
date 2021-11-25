if ! command -v multipass
then
    echo "installing multipass"
    sudo snap install multipass
    sleep 10
fi
firstStart=false
if [[ $(multipass info --all) ]];
then 
    echo "found multipass instances"
else
    firstStart=true
    echo "launching multipass nodes "
    # https://linuxcontainers.org/lxd/introduction/#get-started
    sudo snap install lxd
    lxd init
    multipass set local.driver=lxd

    multipass launch --name master -m 4G -d 20G --network lxdbr0
    multipass launch --name worker0 -m 4G -d 20G
    multipass launch --name worker1 -m 4G -d 20G
    
    var="sudo snap install microk8s --classic --channel=1.19/stable  && \
    sudo usermod -a -G microk8s ubuntu && \
    sudo chown -f -R ubuntu ~/.kube &&\
    microk8s status --wait-ready &&\
    echo "alias kubectl='microk8s kubectl'" >> ~/.bash_aliases &&\
    source ~/.bash_aliases"
              
    echo "installing microk8s"
    multipass exec master -- eval $var  && microk8s enable dns storage     
    multipass exec master -- sudo microk8s.kubectl -n jambonz create secret docker-registry cognigy-registry-token \
        --docker-server=cognigydevelopment.azurecr.io \
        --docker-username=$(printenv DOCKER_USERNAME) \
        --docker-password=$(printenv DOCKER_PASSWORD)
    multipass exec worker0 -- eval $var 
    multipass exec worker1 -- eval $var  

    echo "setting up node labels and taints"
    multipass exec master -- && \
    kubectl label nodes worker1 voip-environment=edge && \
    kubectl label nodes worker0 voip-environment=edge && \
    kubectl taint nodes worker1 voip-edge=true:NoSchedule &&  \
    kubectl taint nodes worker0 voip-edge=media-edge:NoSchedule 
fi

echo "starting services"
multipass mount $PWD master 

multipass exec master -- cd $PWD && kubectl apply -k .
if[[firstStart]]
then
    multipass exec master -- sudo kubectl -n jambonz create secret docker-registry cognigy-registry-token \
        --docker-server=cognigydevelopment.azurecr.io \
        --docker-username=$(printenv DOCKER_USERNAME) \
        --docker-password=$(printenv DOCKER_PASSWORD)
fi
echo "deployment finished"
