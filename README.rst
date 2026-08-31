CouchDB - JSON based Web database
=================================

`CouchDB`_ is a database that completely embraces the web. Store your
data with JSON documents. Access your documents with your web browser,
via HTTP. Query, combine, and transform your documents with JavaScript.
CouchDB works well with modern web and mobile apps. You can even serve
web apps directly out of CouchDB.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- CouchDB installed from the official Apache CouchDB APT repository.
- Nginx pre-configured with SSL support to expose the CouchDB API at
  ``/couchdb`` and Fauxton at ``/couchdb/_utils/``.
- CouchDB bound to loopback and exposed to clients through Nginx.
- CouchDB `Admin Party`_ disabled and user **admin** enabled by default.
- TurnKey Web Control panel with links to Fauxton and useful references.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH: username **root**
-  CouchDB: username **admin**

.. _CouchDB: http://couchdb.apache.org/
.. _Admin Party: http://guide.couchdb.org/draft/security.html#party
.. _TurnKey Core: https://www.turnkeylinux.org/core
