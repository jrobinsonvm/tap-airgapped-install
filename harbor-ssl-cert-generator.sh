#!/bin/bash

# Update the following to match your environment 
URL='registry.test.example.com'
URL2='*.example.com'
IP='10.x.x.170'
DATA_VOL='/data'
PORT='7443'
SUBJ="/C=US/ST=NC/L=Raleigh/O=Somethingelse/OU=Personal/CN='$URL'"

OPENSSLCNF='no need'
for path in /etc/openssl/openssl.cnf /etc/ssl/openssl.cnf /usr/local/etc/openssl/openssl.cnf; do
    if [[ -e ${path} ]]; then
        OPENSSLCNF=${path}
    fi
done
if [[ -z ${OPENSSLCNF} ]]; then
    printf "Could not find openssl.cnf"
    exit 1
fi

# Generate a Certificate Authority Certificate
openssl genrsa -out ca.key 4096

openssl req -x509 -new -nodes -sha512 -days 3650 \
 -subj $SUBJ \
 -key ca.key \
 -out ca.crt

# Generate a Server Certificate 
openssl genrsa -out $URL.key 4096

openssl req -sha512 -new \
 -subj $SUBJ \
 -key $URL.key -out $URL.csr

# Generate the certificate of local registry host
cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=$URL
DNS.2=$URL2
IP.1=$IP
EOF

openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in $URL.csr -out $URL.crt
	
# Copy for harbor
mkdir -p $DATA_VOL/cert
cp $URL.crt $DATA_VOL/cert/server.crt
cp $URL.key $DATA_VOL/cert/server.key

# Convert $URL.crt to $URL.cert, for use by Docker
openssl x509 -inform PEM -in $URL.crt -out $URL.cert

# Copy for Docker
rm -rf /etc/docker/certs.d/$URL*
mkdir -p /etc/docker/certs.d/$URL
cp $URL.cert /etc/docker/certs.d/$URL/
cp $URL.key /etc/docker/certs.d/$URL/
cp ca.crt /etc/docker/certs.d/$URL/
ln -sf /etc/docker/certs.d/$URL /etc/docker/certs.d/$URL:$PORT

# Copy considering the platform
os=`awk -F= '/^NAME/{print $2}' /etc/os-release | sed 's/"//g'`
if [ "$os" == "CentOS Linux" ]; then
    cp $URL.crt /etc/pki/ca-trust/source/anchors/$URL.crt
    update-ca-trust
    echo "CentOS update-ca-trust"
fi
if [ "$os" == "Ubuntu" ]; then
    cp $URL.crt /usr/local/share/ca-certificates/$URL.crt
    update-ca-certificates
    echo "Ubuntu update-ca-certificates"
fi

echo "It's done"

#if you hanve any problem like x509
#check harbor.yml, run ./prepare, run ./install.sh
