# Network VXLAN-EVPN Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-role-network-vxlanevpn

## Overview

This role is used to configure a Linux host for networking.  This role supports
all the various common networking setup you might expect such as network
interfaces, vlans, bonds, and bridges.  In addition, it supports VXLAN EVPN
for those wanting to participate in a pure Layer3 VXLAN EVPN network.

When using VXLAN EVPN, the underlay can be provisioned using BGP Unnnumbered
(using only link-local ip addresses) when the upstream switch is participating
in the VXLAN network. Otherwise specific peers may be specified by referencing
the ansible groups for which participating members are a part of. The BGP stack
in use is FRR.

When using VXLAN EVPN, it is strongly recommended to use a network card that
supports VXLAN offloading such as Mellanox/Nvidia Connect-X4 or better.

This role is initially targeting Ubuntu, and tested on 24.04LTS.  This generates
systemd-networkd configuration directly, so should be portable to any modern
systemd system with minimal effort.

## Variables used by this role

* `network_vtep_ip`: Required when using VXLAN-EVPN. IPv4 address and subnet
  used by the underlay network for VXLAN tunnel endpoints.  This IP address is
  exchanged using BGP to facilitate communication, it must be unique across the
  underlay.  A subnet mask must be specified for the firewall to know what
  address ranges are allowed, however only a `/32` will be advertised.
  e.g. `172.17.0.2/24`
* `network_underlay_asn`: Required when using VXLAN-EVPN. Autonomous System
   Number to use for the underlay. This should be unique across the underly.
   The private ASN range is `64512` to `65534` and `4200000000` to `4294967294`.
* `network_underlay_interfaces`: List of interfaces to use for the underlay
  network.  These are BGP unnumbered interfaces that cannot be used for
  any other purpose.  These interfaces may be an ethernet interface, a
  configured bond, a configured bridge, or a configured vlan interface.  If not
  using this option, then `network_underlay_peergroup` and
  `network_underlay_srcip` must be specified when using VXLAN-EVPN.  This
  configuration must specify only ***one*** of `iface`, `pattern`, `macaddr`,
  or `driver` below.
    * `ifname`: exact interface name, e.g. `ens1`, `enp7s0f0np0`.  This is also
      used if specifying a bond, bridge, or vlan interface created by this role.
    * `pattern`: Regex pattern to match on interface name.  This can add more
      than one interface at a time. e.g. `ens.*`, `ens[23]`
    * `macaddr`: Mac address of interface
    * `driver`: Driver module to match on.  This can add more than one interface
      at a time.  e.g. `mlx5_core`, `ixgbe`
    * `speed`: To set a specific speed in Mb/s, e.g. `10000`, `25000`, `100000`.
      Defaults to whatever the NIC default is.
    * `autonegotiation`: Boolean. Whether or not to enable autonegotiation.
      Default is `true`.
    * `fec`: The FEC type to use. Valid values are: `auto`, `off`, `rs`, `baser`,
      `llrs`. Defaults to `auto` if link speed specified is less than `25000`
      otherwise defaults to `auto` (including if link speed not specifed).
* `network_underlay_peergroups`: If using VXLAN-EVPN but not using BGP
  Unnumbered, specify a *list* of groups that contain members to be peered with.
  Each member of the specified groups must contain `network_underlay_srcip` or
  an error will be thrown.
* `network_underlay_srcip`: If using VXLAN-EVPN but not using BGP
  Unnumbered, this is the source ip address for BGP peering which is required
  for this use-case.
* `network_underlay_mtu`: MTU to use for all underlay interfaces.  Defaults
  to `9100` if not specified.  This must be at least 54 bytes greater than
  the largest `network_vxlans` mtu.
* `network_vxlans`: List of vxlan VNIs to associate with the host.  These must
  be attached to a bridge for the host to use them.
  * `vni`: VXLAN vni (`1` to `16777215`). Required.
  * `bridge`: Bridge to attach vlan to. Required.
  * `vlan`: VLAN to assign to local bridge. Required if bridge is vlan aware.
    ***NOTE***: Currently using vlan aware bridges to attach VXLAN devices does
    not work, this is a WIP.  Please create a non-vlan-aware bridge per vxlan
    for now.
  * `mtu`: MTU. Must be at least 54 bytes less than `network_underlay_mtu` or
    the MTU of the interfaces involved in the BGP EVPN sessions. Defaults to
    `1500`.  Recommended `9000` for Jumbo Frames.
* `network_interfaces`: These are interfaces which do not participate in vxlan,
  bond, or bridge networks. Must specify one (and only one) of `ifname`,
  `pattern`, `macaddr`, or `driver` for interface matching.  Ip address
  and routing information may be associated with a bridge if desired (mostly
  useful for non-vlan-aware bridges).
  * `name`: Name to assign network interface.  Must be specified if not using
    `ifname`.
  * `ifname`: exact interface name, e.g. `ens1`, `enp7s0f0np0`
  * `pattern`: Regex pattern to match on interface name. e.g. `ens.*`, `ens[23]`.
    Care must be taken not to match more than one interface or an error will
    be thrown.
  * `macaddr`: Mac address of interface
  * `driver`: Driver module to match on. e.g. `mlx5_core`, `ixgbe`. Care must be
    taken to not match more than one interface or an error will be thrown.
  * `mtu`: MTU. Defaults to `1500`.  Recommended `9000` for Jumbo Frames.
  * `dhcp`: Default `false`. Set to true to use dhcp (also enables ipv6 RA).
    Cannot be used with `addresses`.
  * `dhcp_allow_learning`: If dhcp is enabled, this is whether to allow learning
    of things like routes (including default route), dns, and ntp.  The default
    is `true`.
  * `addresses`: List of ip (v4 or v6) addresses with subnet mask.  Cannot be
    used with `dhcp`.  e.g.: `10.23.45.2/24`, `2600:1234::2/64`
  * `routes`: List of routes.  If none specified will only be able to access
    other machines in the same subnet.  Typically not used with `dhcp`.
    * `to`: Subnet to add route for.  Use `0.0.0.0/0` or `::/0` for default
      route for ipv4 or ipv6, respectively.
    * `via`: Gateway to use to access specified subnet. e.g. `10.23.45.1` or
      `2600:1234::1`
  * `nameservers`: Dictionary of values for DNS configuration. Typically not
    used with `dhcp`.
    * `addresses`: List of addresses for nameservers,
      e.g. `8.8.8.8` or `2001:4860:4860::8888`
    * `search`: List of search domains, e.g. `internal.example.com`
  * `speed`: To set a specific speed in Mb/s, e.g. `10000`, `25000`, `100000`.
    Defaults to whatever the NIC default is.
  * `autonegotiation`: Boolean. Whether or not to enable autonegotiation.
    Default is `true`.
  * `fec`: The FEC type to use. Valid values are: `auto`, `off`, `rs`, `baser`,
    `llrs`. Defaults to `auto` if link speed specified is less than `25000`
    otherwise defaults to `auto` (including if link speed not specifed).
* `network_bonds`: Create LACP network bonds. Multiple interfaces may be
   specified in a bond, and when using pattern matching or driver matching
   those too may resolve to multiple interfaces.
  * `name`: Interface name to assign for bond.
  * `interfaces`: List of interfaces in the bond. Must specify one (and only
    one of) `ifname`, `pattern`, `macaddr`, or `driver` for interface matching.
    * `ifname`: exact interface name, e.g. `ens1`, `enp7s0f0np0`
    * `pattern`: Regex pattern to match on interface name. e.g. `ens.*`, `ens[23]`.
      Care must be taken not to match more than one interface or an error will
      be thrown.
    * `macaddr`: Mac address of interface
    * `driver`: Driver module to match on. e.g. `mlx5_core`, `ixgbe`. Care must be
      taken to not match more than one interface or an error will be thrown.
    * `speed`: To set a specific speed in Mb/s, e.g. `10000`, `25000`, `100000`.
      Defaults to whatever the NIC default is.
    * `autonegotiation`: Boolean. Whether or not to enable autonegotiation.
      Default is `true`.
    * `fec`: The FEC type to use. Valid values are: `auto`, `off`, `rs`, `baser`,
      `llrs`. Defaults to `auto` if link speed specified is less than `25000`
      otherwise defaults to `auto` (including if link speed not specifed).
  * `mtu`: MTU. Defaults to `1500`.  Recommended `9000` for Jumbo Frames.
  * `dhcp`: Default `false`. Set to true to use dhcp (also enables ipv6 RA).
    Cannot be used with `addresses`.
  * `dhcp_allow_learning`: If dhcp is enabled, this is whether to allow learning
    of things like routes (including default route), dns, and ntp.  The default
    is `true`.
  * `addresses`: List of ip (v4 or v6) addresses with subnet mask.  Cannot be
    used with `dhcp`.  e.g.: `10.23.45.2/24`, `2600:1234::2/64`
  * `routes`: List of routes.  If none specified will only be able to access
    other machines in the same subnet.  Typically not used with `dhcp`.
    * `to`: Subnet to add route for.  Use `0.0.0.0/0` or `::/0` for default
      route for ipv4 or ipv6, respectively.
    * `via`: Gateway to use to access specified subnet. e.g. `10.23.45.1` or
      `2600:1234::1`
  * `nameservers`: Dictionary of values for DNS configuration. Typically not
    used with `dhcp`.
    * `addresses`: List of addresses for nameservers,
      e.g. `8.8.8.8` or `2001:4860:4860::8888`
    * `search`: List of search domains, e.g. `internal.example.com`
* `network_bridges`: Create a network bridge.
  * `name`: Interface name to assign for bridge.
  * `interfaces`: List of interfaces in the bridge. Must specify one of (and
    only one of) `ifname`, `pattern`, `macaddr`, or `driver` for interface
    matching.
    * `ifname`: exact interface name, e.g. `ens1`, `enp7s0f0np0`.  May also
      include the name of a bond created.
    * `pattern`: Regex pattern to match on interface name. e.g. `ens.*`, `ens[23]`.
      Care must be taken not to match more than one interface or an error will
      be thrown.
    * `macaddr`: Mac address of interface
    * `driver`: Driver module to match on. e.g. `mlx5_core`, `ixgbe`. Care must be
      taken to not match more than one interface or an error will be thrown.
    * `speed`: To set a specific speed in Mb/s, e.g. `10000`, `25000`, `100000`.
      Defaults to whatever the NIC default is.
    * `autonegotiation`: Boolean. Whether or not to enable autonegotiation.
      Default is `true`.
    * `fec`: The FEC type to use. Valid values are: `auto`, `off`, `rs`, `baser`,
      `llrs`. Defaults to `auto` if link speed specified is less than `25000`
      otherwise defaults to `auto` (including if link speed not specifed).
  * `stp`: Boolean. Whether or not to enable Spanning Tree Protocol. Default `true`.
  * `vlan_aware`: Boolean. Whether or not the bridge is VLAN aware. Default `true`.
  * `pvid`: When `vlan_aware`, this is the default vlan id.  Required if
    assigning IP addresses to bridge directly.  Default is unset.
  * `mtu`: MTU. Defaults to `9000`.
  * `dhcp`: Default `false`. Set to true to use dhcp (also enables ipv6 RA).
    Cannot be used with `addresses`.
  * `dhcp_allow_learning`: If dhcp is enabled, this is whether to allow learning
    of things like routes (including default route), dns, and ntp.  The default
    is `true`.
  * `addresses`: List of ip (v4 or v6) addresses with subnet mask.  Cannot be
    used with `dhcp`.  e.g.: `10.23.45.2/24`, `2600:1234::2/64`
  * `routes`: List of routes.  If none specified will only be able to access
    other machines in the same subnet.  Typically not used with `dhcp`.
    * `to`: Subnet to add route for.  Use `0.0.0.0/0` or `::/0` for default
      route for ipv4 or ipv6, respectively.
    * `via`: Gateway to use to access specified subnet. e.g. `10.23.45.1` or
      `2600:1234::1`
  * `nameservers`: Dictionary of values for DNS configuration. Typically not
    used with `dhcp`.
    * `addresses`: List of addresses for nameservers,
      e.g. `8.8.8.8` or `2001:4860:4860::8888`
    * `search`: List of search domains, e.g. `internal.example.com`
* `network_vlans`: Create a vlan interface attached to a vlan-aware bridge
  in order for the host to be able to participate in the VLAN.
  * `name`: Interface name to assign for vlan. Required.
  * `vlan`: VLAN id to associate with interface.
  * `mtu`: MTU. Defaults to `1500`.  Recommended `9000` for Jumbo Frames.
  * `dhcp`: Default `false`. Set to true to use dhcp (also enables ipv6 RA).
    Cannot be used with `addresses`.
  * `dhcp_allow_learning`: If dhcp is enabled, this is whether to allow learning
    of things like routes (including default route), dns, and ntp.  The default
    is `true`.
  * `addresses`: List of ip (v4 or v6) addresses with subnet mask.  Cannot be
    used with `dhcp`.  e.g.: `10.23.45.2/24`, `2600:1234::2/64`
  * `routes`: List of routes.  If none specified will only be able to access
    other machines in the same subnet.  Typically not used with `dhcp`.
    * `to`: Subnet to add route for.  Use `0.0.0.0/0` or `::/0` for default
      route for ipv4 or ipv6, respectively.
    * `via`: Gateway to use to access specified subnet. e.g. `10.23.45.1` or
      `2600:1234::1`
  * `nameservers`: Dictionary of values for DNS configuration. Typically not
    used with `dhcp`.
    * `addresses`: List of addresses for nameservers,
      e.g. `8.8.8.8` or `2001:4860:4860::8888`
    * `search`: List of search domains, e.g. `internal.example.com`


***NOTE***: Typically variables will be placed in the host vars, it is
recommended to create a file like `host_vars/host-fqdn.yml` that contains
these settings.

### Example

#### Single Interface
```
network_interfaces:
  - name: "mgmt"
    macaddr: "ac:1f:6b:2d:85:83"
    addresses:
      - "192.168.1.81/24"
    mtu: 1500
    routes:
      - to: 0.0.0.0/0
        via: 192.168.1.1
    nameservers:
      addresses:
        - 8.8.8.8
        - 2001:4860:4860::8888
      search:
        - testenv.bradhouse.dev
```

#### VXLAN EVPN BGP Unnumbered
```
network_vtep_ip: "172.17.0.2"
network_underlay_asn: 4201000002
network_underlay_interfaces:
  - driver: "mlx5_core"
    speed: 25000
    fec: rs
network_underlay_mtu: 9100
network_vxlans:
  - vni: 100
    mtu: 9000
    bridge: "hypervisor"
  - vni: 200
    mtu: 9000
    bridge: "ceph"
  - vni: 2
    mtu: 1500
    bridge: "public"
network_bridges:
  - name: "hypervisor"
    stp: false
    vlan_aware: false
    mtu: 9000
    addresses:
      - "10.10.100.2/24"
      - "2620:1234:100::2/64"
  - name: "ceph"
    stp: false
    vlan_aware: false
    mtu: 9000
    addresses:
      - "10.10.200.2/24"
      - "2620:1234:200::2/64"
  - name: "public"
    stp: false
    vlan_aware: false
    mtu: 1500
    addresses:
      - "10.10.1.2/24"
      - "2620:1234:1::2/64"
    routes:
      - to: "0.0.0.0/0"
        via: "10.10.1.1"
      - to: "::/0"
        via: "2620:1234:1::1/64"
    nameservers:
      addresses:
        - 8.8.8.8
        - 2001:4860:4860::8888
      search:
        - "sn1.example.com"
        - "sn2.example.com"
```

#### VXLAN EVPN via VLAN on Bridge with STP
```
network_vtep_ip: "172.17.0.2"
network_underlay_asn: 4201000002
network_underlay_srcip: "172.18.0.2"
network_underlay_peergroups:
  - "cloudstack_mgmt"
  - "cloudstack_kvm"
network_bridges:
  # Vlan-aware bridge with spanning tree with specified interfaces being trunk ports
  - name "br0"
    interfaces:
      - driver: "mlx5_core"
        speed: 25000
        fec: rs
    mtu: 9100
    stp: true
    vlan_aware: true
  # The rest are VXLAN-specific bridges where various vxlans attach
  - name: "hypervisor"
    stp: false
    vlan_aware: false
    mtu: 9000
    addresses:
      - "10.10.100.2/24"
      - "2620:1234:100::2/64"
  - name: "ceph"
    stp: false
    vlan_aware: false
    mtu: 9000
    addresses:
      - "10.10.200.2/24"
      - "2620:1234:200::2/64"
  - name: "public"
    stp: false
    vlan_aware: false
    mtu: 1500
    addresses:
      - "10.10.1.2/24"
      - "2620:1234:1::2/64"
    routes:
      - to: "0.0.0.0/0"
        via: "10.10.1.1"
      - to: "::/0"
        via: "2620:1234:1::1/64"
    nameservers:
      addresses:
        - 8.8.8.8
        - 2001:4860:4860::8888
      search:
        - "sn1.example.com"
        - "sn2.example.com"
network_vlans:
  - name: "vxlanbgp"
    vlan: 123
    addresses:
      - "172.18.0.2/24" # This matches `network_underlay_srcip` above
    mtu: 9100
    bridge: "br0"
network_vxlans:
  - vni: 100
    mtu: 9000
    bridge: "hypervisor"
  - vni: 200
    mtu: 9000
    bridge: "ceph"
  - vni: 2
    mtu: 1500
    bridge: "public"
```

