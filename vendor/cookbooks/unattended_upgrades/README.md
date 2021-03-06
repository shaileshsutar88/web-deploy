## Description

Configure APT to do unattended upgrades as security fixes are released.

## Requirements

Ubuntu or maybe Debian.

Tested on:

* Ubuntu 10.04 LTS with chef-client 10.14.2
* Ubuntu 12.04 LTS wtih chef-client 10.14.2
* Ubuntu 14.04 LTS with chef-client 11.12.2

## Attributes

The following node attributes are passed to the APT configuration template:

* unattended_upgrades[:upgrade_email] - email to receive notifications
* unattended_upgrades[:auto_reboot] - automatically reboot without confirmation if necessary (default false)
* unattended_upgrades[:enable_upgrades] - enable or disable unattended upgrades (default true)

## Usage

    include_recipe "unattended_upgrades"

## Contributing

https://github.com/mcary/unattended_upgrades

### Testing

    $ vagrant up $ver
    $ vagrant ssh $ver -- sudo sh /vagrant/test.sh

Where $ver is 10.04, 12.04, or 14.04.
