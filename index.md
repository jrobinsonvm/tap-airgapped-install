## Tanzu Application Platform - Unofficial AirGapped Install Guide  
### Quick & Dirty - Getting Started Guide

VMware Tanzu Application Platform is a modular, application-aware platform that provides a rich set of developer tooling and a prepaved path to production to build and deploy software quickly and securely on any compliant public cloud or on-premises Kubernetes cluster.

Tanzu Application Platform simplifies workflows in both the inner loop and outer loop of Kubernetes-based app development:

Inner Loop: The inner loop describes a developer’s local development environment where they code and test apps. The activities that take place in the inner loop include writing code, committing to a version control system, deploying to a development or staging environment, testing, and then making additional code changes.

Outer Loop: The outer loop describes the steps to deploy apps to production and maintain them over time. For example, on a cloud-native platform, the outer loop includes activities such as building container images, adding container security, and configuring continuous integration (CI) and continuous delivery (CD) pipelines.

VMware Tanzu Application Platform provides development teams a pre-paved path to production to get code running on any Kubernetes enabling security and scale. It is an application aware platform that is modular so teams can customize it based on their organization’s preferences. [Read more...](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html)

# Install TAP in an AirGapped TKG Cluster 

## Pre-requisites 
 
 -------
 
#### Install the Tanzu CLI 
 
##### [Please follow the Official Docs for the Tanzu CLI Install](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-tanzu-cli.html#linux-tanzu-cli)

<br/>

#### Install Carvel CLI Tools 
#####  [Download and Setup Carvel.dev CLI Tools ](https://carvel.dev/)
> #### Install Via script (macOS or Linux)
```
wget -O- https://carvel.dev/install.sh | bash
```
>
> #### or with curl...
```
curl -L https://carvel.dev/install.sh | bash
```
>
> #### or Via Homebrew (macOS or Linux)
> Based on github.com/vmware-tanzu/homebrew-carvel.
>
```
brew tap vmware-tanzu/carvel
brew install ytt kbld kapp imgpkg kwt vendir
```

<br/>


#### Only Install Cluster Essentials if you are not using TKGM (Tanzu Kubernetes Grid Multi-Cloud).  
 
#### EKS, AKS, GKE and TKGS all require Cluster Essentials to be installed.   
 
##### [Please follow the Official Docs for the Cluster Essentials Install](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-tanzu-cli.html#tanzu-cluster-essentials)


<br/>

-----------------------------------------------------------------------------------------------------------------------------------

### Relocate TAP Image Bundle to a private registry location 
#### From a device with connectivity to the internet run the following commmand to copy the image bundle and create a tarball




#### Set environment variables for private registry 

```
export INSTALL_REGISTRY_USERNAME=username
export INSTALL_REGISTRY_PASSWORD=YourPassword
export INSTALL_REGISTRY_HOSTNAME=your-registry.yourdomain.com
export TAP_VERSION=1.0.2
export tanzunet_username=username
export tanzunet_password=password
export tanzunet_registry=registry.tanzu.vmware.com
export TBS_DEPENDENCY_VERSION=100.0.283
export REGISTRY_PASSWORD=${INSTALL_REGISTRY_PASSWORD} 
```

### Ensure you are logged into both your private registry and the Tanzu Network Registry.  

```
docker login  ${INSTALL_REGISTRY_HOSTNAME} -u ${INSTALL_REGISTRY_USERNAME} -p ${INSTALL_REGISTRY_PASSWORD}


docker login ${tanzunet_registry} -u ${tanzunet_username} -p ${tanzunet_password}

```



### Copy and save image bundle as a tarball using imgpkg
#### After the tarball has been created transfer the tarball to a device which has access to your private registry.   

```
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION --to-tar /tmp/tap-imagebundle.tar
```

### Once that tarball has been transferred to a device which has access to your private registry, push the tarball to your registry.  

```
imgpkg copy --tar /tmp/tap-imagebundle.tar --to-repo your-registry.yourdomain.com/tap/tap-packages --registry-verify-certs=false
```




<br/>

-----------------------------------------------------------------------------------------------------------------------------------

## From the Kubernetes cluster you wish to install TAP run the following commands.   

### Please create a kubernetes secret with your registry's CA Cert if you plan to leverage a self signed cert with your Harbor registry.   The Kapp Controller will pick up the secret after bouncing the kapp-controller pod.   




#### Carvel Docs for creating K8s Secret with Cert data.   

```
https://carvel.dev/kapp-controller/docs/v0.32.0/controller-config/
```


### Create a namespace to install TAP
```
kubectl create ns tap-install
```



### Create a Kubernetes secret for your private registry and export to all namespaces using the Tanzu CLI 


```
tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces --yes --namespace tap-install
```

### Add the Tanzu Application Platform Repository using the Tanzu CLI 
```
  tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/tap/tap-packages:$TAP_VERSION \
  --namespace tap-install
```

<br/>


### Navigate to the Tanzu Network and download a sample backstage catalog.  
####  Please upload to your git repository of choice for later use.   

----

[Direct Link to Tanzu Network - TAP Example Catalog](https://network.pivotal.io/products/tanzu-application-platform#/releases/1059919/file_groups/6091) 

----


### Create a k8s secret that includes your git ssh key for gitops 

#### Disregard if you do not wish to use gitops 
#### The example below assumes your key is located in ~/.ssh

```
kubectl create secret generic git-ssh     --from-file=./id_rsa     --from-file=./id_rsa.pub     --from-file=./known_hosts

```

### Create a file called tap-values.yml and add the following content.   
#### Edits will need to be made to match your environment.   


```
profile: full
ceip_policy_disclosed: true # The value must be true for installation to succeed
buildservice:
  kp_default_repository: "your-private-registry.com/tap/build-service"
  kp_default_repository_username: "username"
  kp_default_repository_password: "xxxxxxxxxxx"
  ca_cert_data: |
    -----BEGIN CERTIFICATE-----
    MIIF2zCCA8OgAwIBAgIUFx8Okxpb45EjI8owci2kQkdGPEwwDQYJKoZIhvcNAQEN
    REDACTED    REDACTED    REDACTED    REDACTED    REDACTED
    MQ4wDAYDVQQKDAVTYWxlczELMAkGA1UECwwCU0UxMjAwBgNVBAMMKW5vc3NsLmhh
    cmJvci5yZWdpc3RyeS5idWlsZG1vZGVybmFwcHMuY29tMB4XDTIyMDMwODE0MzU0
    NVoXDTMyMDMwNTE0MzU0NVowfTELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAk5DMRAw
    DgYDVQQHDAdSYWxlaWdoMQ4wDAYDVQQKDAVTYWxlczELMAkGA1UECwwCU0UxMjAw
    BgNVBAMMKW5vc3NsLmhhcmJvci5yZWdpc3RyeS5idWlsZG1vZGVybmFwcHMuY29t
    MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAw3Eaetb6AdjzDyUDJD7S
    HmAjsU9kaPln9HPHzNCLQRuYu6P1KGjtchfqeYfFGYVS+BHFBfTNHrOr1ixiTUjB
    REDACTED    REDACTED    REDACTED    REDACTED    REDACTED
    mz2EuatgF+HL9f3hib7Kb7EdR38J0qA0UbJFvFIRG6JwUhBAoA8ALgEPXFjpssa7
    ac4N47jJQNPafWgdm164E7b3oMbcti1uKquMrzZyX+nFnUURhFqyO/GYIga4nbsp
    IEikHs3sXHSCVlAB7wqVaLE1fmAkrgtimRk0TWfdA4flMjadxS29HKaMMFCLMiXh
    BM0rakQeVs1AYWc8H5gNnHxzXvft6pGiBTsZtj9W8DcjmibMA8P9O0hDzF3yF+08
    qNb75/wEwfQBW4E/5ifAxgYj8DZ/3n+eeNmlWZphEWfqeppzenbW7qk/3O5Kts17
    SfLy7AoWzYCudw4rUG0cLoqIihgz+xqL/EYTb/Puvk2/3eiUGJ/q67+4h8AqaLwZ
    67JJkZXbAeU9j/C+mgjnBlk9Qv62ye9iZJIGnG5kPIzMz/pp0iz+toWCABLhIAJj
    uvEFW7RIitqM2Mn5U7Ue2hOSqb5qpV3TnQXJ6RVq1CxxO3lSw4AvFGa87GxV5EBA
    REDACTED    REDACTED    REDACTED    REDACTED    REDACTED
    IIVkc1x8iJ0oMB8GA1UdIwQYMBaAFIQVhH/MATwbOWk5IIVkc1x8iJ0oMA8GA1Ud
    EwEB/wQFMAMBAf8wDQYJKoZIhvcNAQENBQADggIBAGEZ6JqzCByT5mbG8sRxDvEe
    9A6kbDlNtBwMlxekReLG/NMR8xpWB0DtTdbVcpdDgZ7Sw8MZKWdgWtQU2OHiIioT
    Ffczar0AcakYVCOCy3XLSm1+SFJYbd7VNw05hfQo4o7iZynamztoXOToQTinMQVw
    gCiJebDy1EJnZwmPfVwKpjt1lEUKbCT9R+lnFgP2be58kGKbMI2l5/wYN5x8PaI9
    LuKwXmNjEW/e3Gx8mXdFYNgo0MGw5/TeUHyzXel2plGtjy/EcTNx7SO+tSB3J61F
    lbk5mg6nzZxLcyc53zw7MfXqoyabTNKp215u8COBhaOKKZesLSG+kHFuMBGhN79c
    REDACTED    REDACTED    REDACTED    REDACTED    REDACTED
    2oz92PrCflb7P7eGuRrlHsMQCKjdW7CiawuQUieSsV52fY6XzkL5dweE7Jb3N5Ww
    PUqnsCGxzdOEdbdM0UXgPIkVkNb/EgH9MdNzmAcxNC9N6C0dXDgdHqmE9YMaITE3
    hypQ+cIQjdq/5OLJpV7hyzsNdiYldGJqfCT1PfXyYCmQOAy9hQ502tPkoTuhKgdB
    +qZTbauGbxo0IwKDnZmP3f8F6HohKw3Mo0kDH8VTEacah56bX0ujEK/e73z1fsyp
    T5qmfBb6CQj/VK20iKPV
    -----END CERTIFICATE-----
  descriptor_name: "tap-1.0.0-full"
  enable_automatic_dependency_updates: false
supply_chain: basic

contour:
  envoy:
    service:
      type: LoadBalancer

cnrs:
  domain_name: "tap.yourdomain.com"
  
ootb_supply_chain_basic:
  registry:
    server: "your-private-registry.com"
    repository: "tap-demo"
  git_ops:
    ssh_secret: "git-ssh"
  cluster_builder: default
  service_account: default

learningcenter:
  ingressDomain: "tap.yourdomain.com"

tap_gui:
  service_type: LoadBalancer
  ingressEnabled: "true"
  ingressDomain: "tap.yourdomain.com"
  app_config:
    app:
      baseUrl: http://tap-gui.tap.yourdomain.com:7000
    integrations:
      github: # Other integrations available see official docs 
        - host: github.com
          token: "xxxxxxxtokenxxxxxx"
    catalog:
      locations:
        - type: url
          target: https://github.com/jrobinsonvm/tap-latest-demo-catalog/blob/main/catalog-info.yaml # Replace this
    backend:
      baseUrl: http://tap-gui.tap.yourdomain.com:7000
      cors:
        origin: http://tap-gui.tap.yourdomain.com:7000

metadata_store:
  app_service_type: LoadBalancer # (optional) Defaults to LoadBalancer. Change to NodePort for distributions that don't support LoadBalancer

grype:
  namespace: "default" # (optional) Defaults to default namespace.
  targetImagePullSecret: "tap-registry"
```



### Install Tanzu Application Platform 

```
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yml -n tap-install
```

<!-- 
```
tanzu package installed update tap \
 --package-name tap.tanzu.vmware.com \
 --version 1.0.1 -n tap-install \
 -f tap-values.yml
``` -->


<br/>

-----------------------------------------------------------------------------------------------------------------------------------

## Install AirGapped TBS Dependencies 

###  Relocate Images to a Registry (Air-Gapped)

#### First login to the tanzu registry 
```
docker login registry.tanzu.vmware.com
```

#### Now Login to your private registry 
```
docker login ${INSTALL_REGISTRY_HOSTNAME}
```


#### Please see the Tanzu Network to select the latest TBS Dependencies Version
#### This will ensure all images are up to date and free of critical vulnerabilities 

https://network.tanzu.vmware.com/products/tbs-dependencies/

#### The following example will use the 100.0.283 verison 
#### This command will package the image bundle as a tarball 

<br/>

```
 imgpkg copy -b registry.tanzu.vmware.com/tbs-dependencies/full:${TBS_DEPENDENCY_VERSION} \
   --to-tar=tbs-dependencies.tar
```

#### Now let's upload the tarball contents to your private airgapped image registry.   
```
imgpkg copy --tar=tbs-dependencies.tar \
   --to-repo ${INSTALL_REGISTRY_HOSTNAME}/tap/build-service --registry-verify-certs=false
```

#### Now that dependencies are relocated to the internal registry, you can use the following commands to update the necessary resources:

```
 imgpkg pull -b ${INSTALL_REGISTRY_HOSTNAME}/tap/build-service:${TBS_DEPENDENCY_VERSION} \
   -o /tmp/descriptor-bundle --registry-verify-certs=false
```

#### Create a KP secret for your airgapped private registry 
##### In the example I'm using the default namespace as my developer namespace.   Use ' -n namespace-name ' to create the secrets in your developer namespace.   

```
kp secret create registry-credentials --registry ${INSTALL_REGISTRY_HOSTNAME} --registry-user ${INSTALL_REGISTRY_USERNAME}

```

```
kp secret create tap-registry --registry ${INSTALL_REGISTRY_HOSTNAME} --registry-user ${INSTALL_REGISTRY_USERNAME}

```



#### Copy the images from your local machine to the airgapped registry 

```
 kbld -f /tmp/descriptor-bundle/.imgpkg/images.yml \
   -f /tmp/descriptor-bundle/tanzu.descriptor.v1alpha3/descriptor-${TBS_DEPENDENCY_VERSION}.yaml \
   | kp import -f - --registry-verify-certs=false
```

<br/>

<br/>

----

## Before running any workloads you will need to setup permissions for your developer namespace.
### As discussed earlier, we are using the default namespace as our developer namespce for this example.   

<!-- ```
kubectl create ns dev-namespace-1
``` 


### Create a kubernetes secret for the registry you wish to use with your developer namespace.   

```
kubectl create secret docker-registry registry-credentials --docker-server=${INSTALL_REGISTRY_HOSTNAME} --docker-username=${INSTALL_REGISTRY_USERNAME} --docker-password=${INSTALL_REGISTRY_PASSWORD} 
```
-->


### Run the following to setup proper roles and service account permissions 
```
cat <<EOF | kubectl -n default apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: default
rules:
- apiGroups: [source.toolkit.fluxcd.io]
  resources: [gitrepositories]
  verbs: ['*']
- apiGroups: [source.apps.tanzu.vmware.com]
  resources: [imagerepositories]
  verbs: ['*']
- apiGroups: [carto.run]
  resources: [deliverables, runnables]
  verbs: ['*']
- apiGroups: [kpack.io]
  resources: [images]
  verbs: ['*']
- apiGroups: [conventions.apps.tanzu.vmware.com]
  resources: [podintents]
  verbs: ['*']
- apiGroups: [""]
  resources: ['configmaps']
  verbs: ['*']
- apiGroups: [""]
  resources: ['pods']
  verbs: ['list']
- apiGroups: [tekton.dev]
  resources: [taskruns, pipelineruns]
  verbs: ['*']
- apiGroups: [tekton.dev]
  resources: [pipelines]
  verbs: ['list']
- apiGroups: [kappctrl.k14s.io]
  resources: [apps]
  verbs: ['*']
- apiGroups: [serving.knative.dev]
  resources: ['services']
  verbs: ['*']
- apiGroups: [servicebinding.io]
  resources: ['servicebindings']
  verbs: ['*']
- apiGroups: [services.apps.tanzu.vmware.com]
  resources: ['resourceclaims']
  verbs: ['*']
- apiGroups: [scanning.apps.tanzu.vmware.com]
  resources: ['imagescans', 'sourcescans']
  verbs: ['*']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: default
subjects:
  - kind: ServiceAccount
    name: default
EOF

```


### Now you are ready to run some workloads

<br/>

#### But first take a look at the Supply Chain you will be using.
```
tanzu apps cluster-supply-chain list
```

<br/>

### Now try kicking off the following example workload deployment 

####  Since you are running in an air-gapped environment you may need to copy and push the git repo below to your internal git repository.   

```
https://github.com/sample-accelerators/tanzu-java-web-app
```

<br/>

### Deploy the following workload 

```
tanzu apps workload create java-web \
--git-repo https://github.com/sample-accelerators/tanzu-java-web-app \
--git-branch main \
--type web \
--label app.kubernetes.io/part-of=tanzu-java-web-app \
--label tanzu.app.live.view="true" \
--label tanzu.app.live.view.application.name="java-web" 
```

<!-- ```
tanzu apps workload create pet \
--git-repo https://github.com/jrobinsonvm/spring-petclinic.git \
--git-branch main \
--type web \
--label app.kubernetes.io/part-of=tanzu-test \
--label tanzu.app.live.view="true" \
--label tanzu.app.live.view.application.name="petsclinc" \ 
--yes
``` -->


### Check deployed apps / Workloads 
```
tanzu apps workload list
```


<br/>

-------------

### To make updates or changes to your TAP Installation (tap-values.yml) run the following command.   

```
tanzu package installed update tap \
 --package-name tap.tanzu.vmware.com \
 --version 1.0.2 -n tap-install \
 -f tap-values.yml
 ```
 
 
<!--  
 ## Let's now leverage one of our out of the box testing and scanning supply chains

```
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: developer-defined-tekton-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: test      # (!) required
spec:
  params:
    - name: source-url                        # (!) required
    - name: source-revision                   # (!) required
  tasks:
    - name: test
      params:
        - name: source-url
          value: $(params.source-url)
        - name: source-revision
          value: $(params.source-revision)
      taskSpec:
        params:
          - name: source-url
          - name: source-revision
        steps:
          - name: test
            image: gradle
            script: |-
              cd `mktemp -d`
              wget -qO- $(params.source-url) | tar xvz -m
              ./mvnw test
```
 -->


 
For more details see the offical [Tanzu Application Platform](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html)
