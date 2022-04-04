## Quick &  Dirty steps to SSH to each node and modify the etc hosts file.    

```
kubectl get tkc -A 
```

```
kubectl get secrets -n <namespace-name> <guest-cluster-name>-ssh-password -o yaml
```

```
echo "<encoded-password-from-above>" |base64 --decode
```

### On each node do the following:

```
ssh vmware-system-user@<TKGS-CLUSTER-NODE-IP-ADDRESS> 
vi /etc/hosts # modify /etc/hosts file to include hardcoded fqdn 
```
