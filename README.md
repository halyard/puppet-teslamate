puppet-teslamate
===========

[![Puppet Forge](https://img.shields.io/puppetforge/v/halyard/teslamate.svg)](https://forge.puppetlabs.com/halyard/teslamate)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/halyard/puppet-teslamate/build.yml?branch=main)](https://github.com/halyard/puppet-teslamate/actions)
[![MIT Licensed](http://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://tldrlegal.com/license/mit-license)

Module to configure [teslamate](https://github.com/adriankumpf/teslamate). Does not create a new grafana instance; point your existing Grafana at the Postgres database.

## Usage

```puppet
include teslamate
```
## License

teslamate is released under the MIT License. See the bundled LICENSE file for details.

