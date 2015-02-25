Ansible Playbook to Install WIDE Cloud Controller
=================================================

Create ssh sec/pub keys for the www-data user
---------------------------------------------

You need to create a pair of ssh sec/pub keys for the www-data user
which user is used to check hypervisor status with ssh periodically.

The playbook expects that the following two files are located in
the `${playbook_path}/roles/www-data/files/` directory.

- `id_rsa`
- `id_rsa.pub`


Create certificate files for libvirt and qemu
---------------------------------------------

A certificate authority files and server/client secret
keys/certificate files are required.  The playbook expects that the
following files are located at the
`${playbook_path}/roles/libvirt/files/` directory

- `cacert.pem`
- HOST1`.clientkey.pem`
- HOST1`.clientcert.pem`
- HOST1`.serverkey.pem`
- HOST1`.servercert.pem`
- HOST2`.clientkey.pem`
- ... and so on

HOSTx should be replaced with your WCC node names.


Update Ansible inventory file
-----------------------------

Finally, you need to update the inventory file provided as `hosts` in
the top directory of the playbook.  You have to replace the host names
defined under the `controller`, `hypervisors`, `fileserver`, and `all`
groups.

You also need to update other variables defined for each group.  For
the detailed information of each variables, please consult the WCC
source code.


