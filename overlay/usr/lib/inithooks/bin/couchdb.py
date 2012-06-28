#!/usr/bin/python
"""Set CouchDB admin password

Option:
    --pass=     unless provided, will ask interactively

"""

import sys
import getopt
import hashlib
from uuid import uuid4

from executil import system, ExecError
from dialog_wrapper import Dialog

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass='])
    except getopt.GetoptError, e:
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

    salt = str(uuid4()).replace('-', '')
    hash = hashlib.sha1(password + salt).hexdigest()
    hashpass = "-hashed-%s,%s" % (hash, salt)

    conf = "/etc/couchdb/local.ini"
    system("sed -i \"s|^admin =.*|admin = %s|\" %s" % (hashpass, conf))

    # restart couchdb if running so change takes effect
    try:
        system("/etc/init.d/couchdb status >/dev/null 2>&1")
        system("/etc/init.d/couchdb restart")
    except ExecError, e:
        pass
    

if __name__ == "__main__":
    main()

