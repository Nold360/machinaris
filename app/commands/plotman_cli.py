#
#
#

import datetime
import os
import time
import traceback

from flask import Flask, jsonify, abort, request, flash
from subprocess import Popen, TimeoutExpired, PIPE
from app.models import plotman
from app import app

PLOTMAN_SCRIPT = '/chia-blockchain/venv/bin/plotman'

RELOAD_MINIMUM_SECS = 30 # Don't query plotman unless at least this long since last time.

last_plotting_summary = None 
last_plotting_summary_load_time = None 

def load_plotting_summary():
    global last_plotting_summary
    global last_plotting_summary_load_time
    if last_plotting_summary and last_plotting_summary_load_time >= \
            (datetime.datetime.now() - datetime.timedelta(seconds=RELOAD_MINIMUM_SECS)):
        return last_plotting_summary

    proc = Popen("{0} {1} < /dev/tty".format(PLOTMAN_SCRIPT,'status'), stdout=PIPE, stderr=PIPE, shell=True)
    try:
        outs, errs = proc.communicate(timeout=30)
    except TimeoutExpired:
        proc.kill()
        proc.communicate()
        abort(500, description="The timeout is expired!")
    if errs:
        app.logger.error(errs.decode('utf-8'))
        abort(500, description=errs.decode('utf-8'))
    
    cli_stdout = outs.decode('utf-8')
    #app.logger.info("Here is: {0}".format(cli_stdout))
    last_plotting_summary = plotman.PlottingSummary(cli_stdout.splitlines())
    last_plotting_summary_load_time = datetime.datetime.now()
    return last_plotting_summary

def start_plot_run():
    global last_plotting_summary
    app.logger.info("Starting Plotman run....")
    try:
        logfile = "/root/.chia/logs/plotman.log"
        log_fd = os.open(logfile, os.O_RDWR|os.O_CREAT)
        log_fo = os.fdopen(log_fd, "w+")
        proc = Popen("{0} {1} </dev/tty".format(PLOTMAN_SCRIPT,'plot'), \
            shell=True, universal_newlines=True, stdout=log_fo, stderr=log_fo)
    except:
        traceback.print_exc()
        flash('Failed to start Plotman plotting run!', 'danger')
        flash('Please look in plotman log: {0}'.format(logfile), 'warning')
    else:
        last_plotting_summary = None # Force a refresh on next load
        flash('Plotman started successfully.', 'success')
        time.sleep(5) # Wait for Plotman to start a plot running for display in table
    