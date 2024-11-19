#!/usr/bin/env python3
# coding=utf-8

import flask
import json
import os
import requests
import subprocess
import argparse
import base64
from datetime import datetime
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

app = flask.Flask(__name__)

@app.route('/redfish/v1/')
def root_resource():
    return flask.render_template('root.json')

@app.route('/redfish/v1/Managers')
def manager_collection_resource():
    return flask.render_template('managers.json')

@app.route('/redfish/v1/Systems')
def system_collection_resource():
    return flask.render_template('systems.json')

@app.route('/redfish/v1/Systems/1', methods=['GET', 'PATCH'])
def system_resource():
    username, password = get_credentials(flask.request)
    global bmc_ip
    global power_state
    if flask.request.method == 'GET':
       return flask.render_template(
           'fake_system.json',
           power_state=power_state,
        )
    else:
       app.logger.info('patch request') 
       boot = flask.request.json.get('Boot')
       if not boot:
           return ('PATCH only works for Boot'), 400
       if boot:
           target = boot.get('BootSourceOverrideTarget')
           mode = boot.get('BootSourceOverrideMode')
           if not target and not mode:
               return ('Missing the BootSourceOverrideTarget and/or '
                       'BootSourceOverrideMode element', 400)
           else:
               app.logger.info('Running script that sets boot from VirtualCD once')
               try:
                   my_env = set_env_vars(bmc_ip, username, password)
                   subprocess.check_call(['custom_scripts/bootfromcdonce.sh'], env=my_env)
               except subprocess.CalledProcessError as e:
                   return ('Failed to set boot from virtualcd once', 400)

               return '', 204

@app.route('/redfish/v1/Systems/1/EthernetInterfaces', methods=['GET'])
def manage_interfaces():
    return flask.render_template('fake_interfaces.json')

@app.route('/redfish/v1/Managers/1', methods=['GET'])
def manager_resource():
    return flask.render_template(
           'fake_manager.json',
           date_time=datetime.now().strftime('%Y-%M-%dT%H:%M:%S+00:00'),
        )

@app.route('/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
           methods=['POST'])
def system_reset_action():
    global bmc_ip
    username, password = get_credentials(flask.request)
    reset_type = flask.request.json.get('ResetType')
    global power_state 
    if reset_type == 'On':
        app.logger.info('Running script that powers on the server')
        try:
            my_env = set_env_vars(bmc_ip, username, password)
            subprocess.check_call(['custom_scripts/poweron.sh'], env=my_env)
        except subprocess.CalledProcessError as e:
            return ('Failed to poweron the server', 400)
        power_state = 'On'
    else:
        app.logger.info('Running script that powers off the server')
        try:
            my_env = set_env_vars(bmc_ip, username, password)
            subprocess.check_call(['custom_scripts/poweroff.sh'], env=my_env)
        except subprocess.CalledProcessError as e:
            return ('Failed to poweroff the server', 400)
        power_state = 'Off'

    return '', 204


@app.route('/redfish/v1/Managers/1/VirtualMedia', methods=['GET'])
def virtualmedia_collection_resource():
    return flask.render_template('virtualmedias.json')

@app.route('/redfish/v1/Managers/1/VirtualMedia/Cd', methods=['GET'])
def virtualmedia_cd_resource():
    global inserted
    return flask.render_template(
        'virtualmedia_cd.json',
        inserted=inserted,
        image_url=image_url,
        )

@app.route('/redfish/v1/Managers/1/VirtualMedia/Cd/Actions/VirtualMedia.InsertMedia',
          methods=['POST'])
def virtualmedia_insert():
    global bmc_ip
    username, password = get_credentials(flask.request)
    image = flask.request.json.get('Image')
    if not image:
        return('POST only works for Image'), 400
    else:
        global inserted
        global image_url
        inserted = True
        image_url = image
        app.logger.info('Running script that mounts cd with iso %s', image)
        try:
            my_env = set_env_vars(bmc_ip, username, password)
            subprocess.check_call(['custom_scripts/mountcd.sh', image_url], env=my_env)
        except subprocess.CalledProcessError as e:
            return ('Failed to mount virtualcd', 400)
        return '', 204

@app.route('/redfish/v1/Managers/1/VirtualMedia/Cd/Actions/VirtualMedia.EjectMedia',
          methods=['POST'])
def virtualmedia_eject():
    global bmc_ip
    global inserted
    global image_url
    username, password = get_credentials(flask.request)
    inserted = False
    image_url = ''
    app.logger.info('Running script that unmounts cd')
    try:
        my_env = set_env_vars(bmc_ip, username, password)
        subprocess.check_call(['custom_scripts/unmountcd.sh'], env=my_env)
    except subprocess.CalledProcessError as e:
        return ('Failed to unmount virtualcd', 400)
    return '', 204


def get_credentials(flask_request):
    auth = flask_request.headers.get('Authorization', None)
    username = ''
    password = ''
    if auth is not None and auth.startswith('Basic '):
        encoded_creds = auth.split(' ', 1)[1]
        decoded_creds = base64.b64decode(encoded_creds).decode('utf-8')
        username, password = decoded_creds.split(':', 1)
    app.logger.debug('Returning credentials')
    app.logger.debug('Username: ' + username + ', password: ' + password)
    return username, password

def set_env_vars(bmc_endpoint, username, password):
    global vm_name
    my_env = os.environ.copy()
    my_env["BMC_ENDPOINT"] = bmc_endpoint
    my_env["BMC_USERNAME"] = username
    my_env["BMC_PASSWORD"] = password
    try:
        my_env["VM_NAME"] = vm_name
    except:
        pass
    
    return my_env

def run(port, debug, tls_mode, cert_file, key_file):
    """

    """
    if tls_mode == 'adhoc':
        app.run(host='::', port=port, debug=debug, ssl_context='adhoc')
    elif tls_mode == 'disabled':
        app.run(host='::', port=port, debug=debug)
    else:
        if os.path.exists(cert_file) and os.path.exists(key_file):
            app.run(host='::', port=port, debug=debug, ssl_context=(cert_file, key_file))
        else:
            app.logger.error('%s or %s not found.', cert_file, key_file)
            exit()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='FakeFish, an experimental RedFish proxy that calls shell scripts for executing hardware actions.')
    parser.add_argument('--tls-mode', type=str, choices=['adhoc', 'self-signed', 'disabled'], default='adhoc', help='Configures TLS mode. \
                        \'self-signed\' mode expects users to configure a cert and a key files. (default: %(default)s)')
    parser.add_argument('--cert-file', type=str, default='./cert.pem', help='Path to the certificate public key file. (default: %(default)s)')
    parser.add_argument('--key-file', type=str, default='./cert.key', help='Path to the certificate private key file. (default: %(default)s)')
    parser.add_argument('-r', '--remote-bmc', type=str, required=True, help='The BMC IP this FakeFish instance will connect to. e.g: 192.168.1.10')
    parser.add_argument('-p','--listen-port', type=int, required=False, default=9000, help='The port where this FakeFish instance will listen for connections.')
    parser.add_argument('--vm-name', type=str, required=False, help='For KVM Scripts this is the VM domain name in virsh.')
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()

    bmc_ip = args.remote_bmc
    port = args.listen_port
    debug = args.debug
    tls_mode = args.tls_mode
    cert_file = args.cert_file
    key_file = args.key_file
    vm_name = args.vm_name

    inserted = False
    image_url = ''
    power_state = 'On'
    run(port, debug, tls_mode, cert_file, key_file)
