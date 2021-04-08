#!/usb/bin/env python3
#
# Cloud monitoring server to get commands from Slurm to start and stop cloud nodes
#
import socket
import sys
import os
import subprocess
import signal
import stat
import json
from shlex import quote

server_address = 'cloud_socket'
system_nodes = set()
taken_nodes = set()
node_names = dict() # docker tag -> requested hostname
avail_nodes = None

# Make sure the socket does not already exist
try:
    os.unlink(server_address)
except OSError:
    if os.path.exists(server_address):
        raise

# Create a UDS socket
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.bind(server_address)
#allow anyone to write to the socket
os.chmod(server_address, stat.S_IROTH | stat.S_IWOTH)

# Listen for incoming connections
sock.listen(1)

sys.argv.pop(0)
process = subprocess.run(sys.argv)

process = subprocess.run(["docker-compose", "ps", "-q"], capture_output=True)

system_nodes = set(process.stdout.decode('utf-8').split("\n"))

def update_nodes():
    global avail_nodes, system_nodes, taken_nodes

    process = subprocess.run(["docker-compose", "ps", "-q"], capture_output=True)
    found_nodes = set(process.stdout.decode('utf-8').split("\n"))
    avail_nodes = found_nodes - system_nodes - taken_nodes
    #todo missing nodes?

#    for node in new_nodes:
#        process = subprocess.run(["docker", "inspect", node], capture_output=True)
#        props = json.loads(process.stdout)
#
#        if props is not None:
#            nodes.add(node)

while True:
    connection=None
    try:
        print('waiting for a connection', file=sys.stderr)
        connection, client_address = sock.accept()
        print('new connection', file=sys.stderr)

        connection.settimeout(10)
        data = connection.recv(4096).decode('utf-8').strip()
        connection.shutdown(socket.SHUT_RD)
        print('received "%s"' % (data), file=sys.stderr)
        if data:
            op = data.split(":", 1)
            if op[0] == "stop":
                tag=node_names[op[1]]

                os.system("docker rm -f \"%s\"" % (quote(tag)))
                taken_nodes.remove(tag)
                node_names.pop(tag, None)
                connection.sendall(b'ACK')
            elif op[0] == "start":
                #increase node count by 1
                update_nodes()

                os.system("docker-compose up --scale cloud=%s -d" % \
                        (len(avail_nodes) + len(taken_nodes) + 1))

                update_nodes()

                if len(avail_nodes) > 0:
                    node = avail_nodes.pop()
                    node_names[op[1]] = node

                    connection.sendall(node.encode('utf-8'))
                else:
                    connection.sendall(b'FAIL')
            elif op[0] == "whoami":
                update_nodes()

                if len(avail_nodes) > 0:
                    node = avail_nodes.pop()
                    name = None

                    for key, value in node_names.items():
                        if value == node:
                            name = key
                            break

                    if name is None:
                        print("responding FAIL - no nodes avail", file=sys.stderr)
                        connection.sendall(b'FAIL')
                    else:
                        print("responding: %s=%s" % (name, node), file=sys.stderr)
                        taken_nodes.add(node)

                        connection.sendall(name.encode('utf-8'))
                else:
                    connection.sendall(b'FAIL')
            else:
                connection.sendall(b'FAIL')

        connection.close()
    except socket.timeout:
        print('connection timeout', file=sys.stderr)
    except BrokenPipeError:
        print('ignoring broken pipe', file=sys.stderr)
    except KeyboardInterrupt:
        print('shutting down', file=sys.stderr)
        break;

sock.close()
os.unlink(server_address)

#stop the containers
os.system("make stop")
