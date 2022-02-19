#!/usr/bin/python3
"""Set CouchDB admin password

Option:
    --pass=     unless provided, will ask interactively

"""

import sys
import getopt
import hashlib
from uuid import uuid4

import subprocess
from libinithooks.dialog_wrapper import Dialog

def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "CouchDB Password",
            "Enter new password for the CouchDB 'admin' account.")

    conf = "/opt/couchdb/etc/local.d/10-admins.ini"
    subprocess.run(
            ["sed", "-i", "s|^admin =.*|admin = %s|" % password, conf])

    # restart couchdb if running so change takes effect
    subprocess.run(["systemctl", "is-active", "--quiet", "couchdb.service"])
    subprocess.run(["service", "couchdb", "restart"])

if __name__ == "__main__":
    main()

