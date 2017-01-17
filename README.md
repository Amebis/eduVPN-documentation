# Introduction

This is the eduvpn documentation repository. You can find documents, scripts
and deploy instructions for various deployment scenarios.

# Features

- OpenVPN server accepting connections on various UDP ports and `tcp/443`;
- Support (out of the box) multiple UDP instances for load sharing purposes;
- Full IPv6 support inside the VPN tunnel and outer tunnel;
- Support both NAT and routable IP addresses;
- CA for managing client certificates;
- User Portal to allow users to manage their configurations for their 
  devices;
- Multi Language support in the User Portal;
- OAuth 2.0 [API](API.md) for integration with applications;
- Admin Portal manage users, configurations and connections;
- [Two-factor authentication](2FA.md) (TOTP, YubiKey) support with user 
  self-enrollment for both access to the portal(s) and the VPN;
- [Deployment scenarios](PROFILE_CONFIG.md):
  - Route all traffic over the VPN (for safer Internet usage on untrusted 
    networks);
  - Route only some traffic over the VPN (for access to the organization 
    network);
  - Client-to-client only networking;
- Support multiple deployment scenarios [simultaneously](MULTI_PROFILE.md);
- Support [multiple instances](MULTI_INSTANCE.md);
- Support for [multiple nodes](DISTRIBUTED_NODES.md) in different locations;
- Group [ACL](ACL.md) support, including [VOOT](http://openvoot.org/);
- Ability to disable all OpenVPN logging (default);

# Client Support

The VPN server is working with and tested on a variety of platforms and 
clients:

  - Windows (OpenVPN Community Client, Viscosity)
  - OS X (Tunnelblick, Viscosity)
  - Android (OpenVPN for Android, OpenVPN Connect)
  - iOS (OpenVPN Connect)
  - Linux (NetworkManager/CLI)

# Architecture

The architecure is described in a [separate document](ARCHITECTURE.md).

# Authentication 

By default a user name/password login on the User/Admin portal is used, but it 
is easy to enable SAML authentication for identity federations, this is 
documented separately. See [SAML](SAML.md).

For connecting to the VPN service by default only certificates are used, no 
additional user name/password authentication. It is possible to enable 
[2FA](2FA.md) to require an additional TOTP or YubiKey.

# Deployment

You can use a test deploy with the button below to test the software in its 
most basic configuration for free for 2 hours! After the VM started you need
to wait for a bit for the deploy scripts to finish running, then you can browse
to the IP address using a web browser and go from there.

[![Dply](https://dply.co/b.svg)](https://dply.co/b/Sck1PeeV) 

For more control see the [Fedora](FEDORA_VPN_SERVER.md) document, it contains 
all steps to get the software running on a fresh Fedora VM, with more advanced
features like port sharing, TLS using Let's Encrypt and two-factor 
authentication.

The deployment was succesfully tested on the official Fedora 25 cloud image, 
as well as the Fedora 25 image @ [DigitalOcean](https://www.digitalocean.com/).

# Advanced
For simple one server deployments and tests, we have a deploy script available 
you can run on a fresh CentOS 7 installation. It will configure all components 
and will be ready to use after running!

Not all "cloud" instances will work, because they modify CentOS, by e.g. 
disabling SELinux or other (network) changes. We test only with the official 
CentOS [Minimal ISO](https://centos.org/download/) and the official 
[Cloud](https://wiki.centos.org/Download) images.

**NOTE**: make sure SELinux is **enabled** and the filesystem correctly 
(re)labeled! Look [here](https://wiki.centos.org/HowTos/SELinux).

    $ curl -L -O https://github.com/eduvpn/documentation/archive/master.tar.gz
    $ tar -xzf master.tar.gz
    $ cd documentation-master

Modify `deploy.sh` to set `INSTANCE` to the FQDN DNS name of the host you want 
to use for the server, e.g. `vpn.example` and modify the `EXTERNAL_IF` 
parameter to point to the adapter connecting to the Internet, e.g. `eth0`.

Make sure the host name configured in `INSTANCE` can be resolved through DNS.

To run the script:

    $ sudo ./deploy.sh

For more advanced deployment scenarios using multiple nodes, see the 
documentation on [distributed nodes](DISTRIBUTED_NODES.md).

## Users

By default there is a user `me` with a generated password for the User Portal
and a user `admin` with a generated password for the Admin Portal. Those are
printed at the end of the deploy script.

If you want to update/add users you can use the `vpn-user-portal-add-user` and
`vpn-admin-portal-add-user` scripts:

    $ sudo vpn-user-portal-add-user --instance vpn.example --user john --pass s3cr3t

Or to update the existing `admin` password:

    $ sudo vpn-admin-portal-add-user --instance vpn.example --user admin --pass 3xtr4s3cr3t

## CA certificate
You can request a certificate from your CA after running the script for the 
web server. The script put a `vpn.example.csr` file in the directory you ran 
the script from.

Once you obtained the certificate, you can overwrite 
`/etc/pki/tls/certs/vpn.example.crt` with the certificate you obtained and 
configure the certificate chain as well in `/etc/httpd/conf.d/ssl.conf`. Feel
free to use [Let's Encrypt](https://letsencrypt.org/).

Make sure you check the configuration with 
[https://www.ssllabs.com/ssltest/](https://www.ssllabs.com/ssltest/)!
