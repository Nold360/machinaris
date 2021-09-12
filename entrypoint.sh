#
#  Configure and start plotting and farming services.
#

# Always launch Chia - required blockchain
/usr/bin/bash /machinaris/scripts/chia_launch.sh

# Optionally launch forked blockchains for multi-farming
if [[ ${blockchains} =~ flax ]]; then
  /usr/bin/bash /machinaris/scripts/flax_launch.sh
fi

# Build bladebit plotter on first run of container
/usr/bin/bash /machinaris/scripts/bladebit_make.sh

# Launch Machinaris web server and other services
/machinaris/scripts/start_machinaris.sh

while true; do sleep 30; done;
