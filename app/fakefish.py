#!/usr/bin/env python3
# coding=utf-8

import flask
import json
import os
import re
import requests
import subprocess
import argparse
import base64
import sys
from datetime import datetime
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

app = flask.Flask(__name__)

@app.before_request
def validate_credentials():
    valid_username = app.config.get('VALID_USERNAME')
    valid_password = app.config.get('VALID_PASSWORD')
    if valid_username is None and valid_password is None:
        return None
    auth = flask.request.headers.get('Authorization', None)
    if auth is None or not auth.startswith('Basic '):
        return flask.Response(
            'Authentication required', 401,
            {'WWW-Authenticate': 'Basic realm="FakeFish"'})
    try:
        encoded_creds = auth.split(' ', 1)[1]
        decoded_creds = base64.b64decode(encoded_creds).decode('utf-8')
        username, password = decoded_creds.split(':', 1)
    except Exception:
        return flask.Response(
            'Invalid authentication header', 401,
            {'WWW-Authenticate': 'Basic realm="FakeFish"'})
    if username != valid_username or password != valid_password:
        return flask.Response(
            'Invalid credentials', 401,
            {'WWW-Authenticate': 'Basic realm="FakeFish"'})
    return None

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
               except ValueError as e:
                   return (str(e), 400)
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
        except ValueError as e:
            return (str(e), 400)
        except subprocess.CalledProcessError as e:
            return ('Failed to poweron the server', 400)
        power_state = 'On'
    else:
        app.logger.info('Running script that powers off the server')
        try:
            my_env = set_env_vars(bmc_ip, username, password)
            subprocess.check_call(['custom_scripts/poweroff.sh'], env=my_env)
        except ValueError as e:
            return (str(e), 400)
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
    if not re.match(r'^https?://[a-zA-Z0-9._~:/?#@&+,;=%-]+$', image):
        return ('Invalid Image URL'), 400
    else:
        global inserted
        global image_url
        inserted = True
        image_url = image
        app.logger.info('Running script that mounts cd with iso %s', image)
        try:
            my_env = set_env_vars(bmc_ip, username, password)
            subprocess.check_call(['custom_scripts/mountcd.sh', image_url], env=my_env)
        except ValueError as e:
            return (str(e), 400)
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
    except ValueError as e:
        return (str(e), 400)
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
    app.logger.debug('Username: ' + username + ', password: ****')
    return username, password

def set_env_vars(bmc_endpoint, username, password):
    for name, value in [('username', username), ('password', password)]:
        if any(ord(c) < 32 or ord(c) == 127 for c in value):
            raise ValueError(
                'BMC %s contains invalid characters (control characters '
                'are not allowed)' % name)
    my_env = os.environ.copy()
    my_env["BMC_ENDPOINT"] = bmc_endpoint
    my_env["BMC_USERNAME"] = username
    my_env["BMC_PASSWORD"] = password
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
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--validate-credentials', type=str, default=None,
                        help='Path to a file containing username:password for credential validation. '
                             'When set, FakeFish will validate incoming Basic Auth credentials against '
                             'the ones stored in this file before processing any request. '
                             'This is meant for backends that do not validate credentials themselves '
                             '(e.g. KubeVirt, which relies on a KUBECONFIG file). For backends that '
                             'forward credentials to a real BMC (e.g. Dell, Supermicro, HPE), the BMC '
                             'already validates credentials, so this option is not needed, and if set, will cause issues.')
    args = parser.parse_args()

    bmc_ip = args.remote_bmc
    port = args.listen_port
    debug = args.debug
    tls_mode = args.tls_mode
    cert_file = args.cert_file
    key_file = args.key_file

    # Load and cache credentials if --validate-credentials is set
    valid_username = None
    valid_password = None
    if args.validate_credentials:
        creds_path = args.validate_credentials
        if not os.path.exists(creds_path):
            print('ERROR: Credentials file not found: %s' % creds_path, file=sys.stderr)
            sys.exit(1)
        with open(creds_path, 'r') as f:
            creds_line = f.readline().strip()
        valid_username, sep, valid_password = creds_line.partition(':')
        if not sep or not valid_username or not valid_password:
            print('ERROR: Invalid credentials file format. Expected non-empty username:password', file=sys.stderr)
            sys.exit(1)
        app.logger.info('Credential validation enabled from file: %s', creds_path)

    app.config['VALID_USERNAME'] = valid_username
    app.config['VALID_PASSWORD'] = valid_password

    inserted = False
    image_url = ''
    power_state = 'On'
    run(port, debug, tls_mode, cert_file, key_file)
