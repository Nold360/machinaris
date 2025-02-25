#!/bin/env bash
#
# Installs chia-plotter (pipelined multi-threaded)
# See https://github.com/madMAx43v3r/chia-plotter
#

MADMAX_BRANCH=master

# Checkout the project
cd /
git clone --branch ${MADMAX_BRANCH} https://github.com/madMAx43v3r/chia-plotter.git 

# Build the code
cd chia-plotter
git submodule update --init
./make_devel.sh

# Add to path and delete build folder
mkdir -p /usr/lib/chia-plotter
cp -r ./build/* /usr/lib/chia-plotter
ln -s /usr/lib/chia-plotter/chia_plot /usr/bin/chia_plot
ln -s /usr/lib/chia-plotter/chia_plot_k34 /usr/bin/chia_plot_k34
cd /
rm -rf chia-plotter

# Validate in path and working
chia_plot --help
