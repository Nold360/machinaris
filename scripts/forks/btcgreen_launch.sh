#!/bin/env bash
#
# Initialize BTCGreen service, depending on mode of system requested
#

cd /btcgreen-blockchain

. ./activate

# Only the /root/.chia folder is volume-mounted so store btcgreen within
mkdir -p /root/.chia/btcgreen
rm -f /root/.btcgreen
ln -s /root/.chia/btcgreen /root/.btcgreen 

mkdir -p /root/.btcgreen/mainnet/log
btcgreen init >> /root/.btcgreen/mainnet/log/init.log 2>&1 

if [[ "${blockchain_db_download}" == 'true' ]] \
  && [[ "${mode}" == 'fullnode' ]] \
  && [[ -f /usr/bin/mega-get ]] \
  && [[ ! -f /root/.btcgreen/mainnet/db/blockchain_v1_mainnet.sqlite ]]; then
  echo "Downloading BTCGreen blockchain DB (many GBs in size) on first launch..."
  echo "Please be patient as takes minutes now, but saves days of syncing time later."
  mkdir -p /root/.btcgreen/mainnet/db/ && cd /root/.btcgreen/mainnet/db/
  # Mega links for BTCGreen blockchain DB from: https://chiaforksblockchain.com/
  mega-get https://mega.nz/folder/uvoEhaaJ#ozryRZYe2wIx-9eyx84nxQ
  mv btcgreen/*mainnet.sqlite btcgreen/*node.sqlite . && rm -rf btcgreen
fi

echo 'Configuring BTCGreen...'
if [ -f /root/.btcgreen/mainnet/config/config.yaml ]; then
  sed -i 's/log_stdout: true/log_stdout: false/g' /root/.btcgreen/mainnet/config/config.yaml
  sed -i 's/log_level: WARNING/log_level: INFO/g' /root/.btcgreen/mainnet/config/config.yaml
  sed -i 's/localhost/127.0.0.1/g' /root/.btcgreen/mainnet/config/config.yaml
fi

# Loop over provided list of key paths
for k in ${keys//:/ }; do
  if [[ "${k}" == "persistent" ]]; then
    echo "Not touching key directories."
  elif [ -s ${k} ]; then
    echo "Adding key at path: ${k}"
    btcgreen keys add -f ${k} > /dev/null
  fi
done

# Loop over provided list of completed plot directories
for p in ${plots_dir//:/ }; do
    btcgreen plots add -d ${p}
done

chmod 755 -R /root/.btcgreen/mainnet/config/ssl/ &> /dev/null
btcgreen init --fix-ssl-permissions > /dev/null 

# Start services based on mode selected. Default is 'fullnode'
if [[ ${mode} == 'fullnode' ]]; then
  for k in ${keys//:/ }; do
    while [[ "${k}" != "persistent" ]] && [[ ! -s ${k} ]]; do
      echo 'Waiting for key to be created/imported into mnemonic.txt. See: http://localhost:8926'
      sleep 10  # Wait 10 seconds before checking for mnemonic.txt presence
      if [ -s ${k} ]; then
        btcgreen keys add -f ${k}
        sleep 10
      fi
    done
  done
  btcgreen start farmer
elif [[ ${mode} =~ ^farmer.* ]]; then
  if [ ! -f ~/.btcgreen/mainnet/config/ssl/wallet/public_wallet.key ]; then
    echo "No wallet key found, so not starting farming services.  Please add your Chia mnemonic.txt to the ~/.machinaris/ folder and restart."
  else
    btcgreen start farmer-only
  fi
elif [[ ${mode} =~ ^harvester.* ]]; then
  if [[ -z ${farmer_address} || -z ${farmer_port} ]]; then
    echo "A farmer peer address and port are required."
    exit
  else
    if [ ! -f /root/.btcgreen/farmer_ca/private_ca.crt ]; then
      mkdir -p /root/.btcgreen/farmer_ca
      response=$(curl --write-out '%{http_code}' --silent http://${farmer_address}:8938/certificates/?type=btcgreen --output /tmp/certs.zip)
      if [ $response == '200' ]; then
        unzip /tmp/certs.zip -d /root/.btcgreen/farmer_ca
      else
        echo "Certificates response of ${response} from http://${farmer_address}:8938/certificates/?type=btcgreen.  Try clicking 'New Worker' button on 'Workers' page first."
      fi
      rm -f /tmp/certs.zip 
    fi
    if [ -f /root/.btcgreen/farmer_ca/private_ca.crt ]; then
      btcgreen init -c /root/.btcgreen/farmer_ca 2>&1 > /root/.btcgreen/mainnet/log/init.log
      chmod 755 -R /root/.btcgreen/mainnet/config/ssl/ &> /dev/null
      btcgreen init --fix-ssl-permissions > /dev/null 
    else
      echo "Did not find your farmer's certificates within /root/.btcgreen/farmer_ca."
      echo "See: https://github.com/guydavis/machinaris/wiki/Workers#harvester"
    fi
    echo "Configuring farmer peer at ${farmer_address}:${farmer_port}"
    btcgreen configure --set-farmer-peer ${farmer_address}:${farmer_port}
    btcgreen configure --enable-upnp false
    btcgreen start harvester -r
  fi
elif [[ ${mode} == 'plotter' ]]; then
    echo "Starting in Plotter-only mode.  Run Plotman from either CLI or WebUI."
fi
