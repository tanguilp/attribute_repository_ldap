# AttributeRepositoryLdap

LDAP implementation of `AttributeRepository`

## Installation

```elixir
def deps do
  [
    {:attribute_repository_ldap, github: "tanguilp/attribute_repository_ldap", tag: "v0.1.1"}
  ]
end
```

## Usage

This modules relies on `LDAPoolex` to create and maintain a pool of connections to LDAP
servers. One shall therefore configure it's server in the relevant configuration files. Example:

```elixir
use Mix.Config

config :ldapoolex, pools: [
  pool_slapd: [
    ldap_args: [hosts: ['localhost'], base: 'dc=example,dc=org'],
    size: 5,
    max_overflow: 10
  ],

  pool_apacheds: [
    ldap_args: [
      hosts: ['localhost'],
      base: 'ou=People,dc=example,dc=com',
      ldap_open_opts: [port: 10_389]
    ],
    size: 2,
    overflow: 7
  ]
]
```

You can also launch a pool manually (see `LDAPoolex` documentation) since this library uses
the pool's name.

This library uses type information of `LDAPoolex`'s loaded pool's schema. If the schema is
not loaded (either because `load_schema: false` was set or schema could not be loaded) all
attributes will be considered multi-valued and of `String.t()` type.

## Resource id

The resource id of the `AttributeRepositoryLdap` implementation is the LDAP distinguished
name (dn).

## Run options

The `AttributeRepository.run_opts()` for this module are the following:
- `:instance`: the `LDAPoolex` pool name (`atom()`). No default, **mandatory**
- `:base_dn`: the base DN where to perform search. No default, **mandatory** except if
you only use the `AttributeRepositoryLdap.get/3` and `AttributeRepositoryLdap.get!/3` functions
- `:search_scope`: scope for LDAP searches. Defaults to `:eldap.singleLevel()`
- `:search_timeout`: timeout for the search operations (used by `get/3` and `search/3`). No
default

## Supported behaviours

- [ ] `AttributeRepository.Install`
- [x] `AttributeRepository.Read`
- [ ] `AttributeRepository.Write`
- [x] `AttributeRepository.Search`
- [x] `AttributeRepository.SupervisedStart`
- [ ] `AttributeRepository.Start`

## Supported attribute types

### Data types

- [x] `String.t()`
- [x] `boolean()` (the `1.3.6.1.4.1.1466.115.121.1.7` OID)
- [ ] `float()` (note: this is not supported by the LDAP data model)
- [x] `integer()` (the `1.3.6.1.4.1.1466.115.121.1.27` OID)
- [x] `DateTime.t()` (the `1.3.6.1.4.1.1466.115.121.1.24` OID also known as *GeneralizedTime*)
- [x] `AttributeRepository.binary_data()` (the `1.3.6.1.4.1.1466.115.121.1.40` OID also known
as *OctetString*)
- [ ] `AttributeRepository.ref()`
- [ ] `nil`
- [ ] `AttributeRepository.object_attribute()` or *complex attribute* (note: this is not supported
by the LDAP data model)

### Cardinality

- [x] Singular attributes
- [x] Multi-valued attributes

## Search support

### Logical operators

- [x] `and`
- [x] `or`
- [x] `not`

### Compare operators

- [x] `eq`
- [x] `ne`
- [x] `gt`
- [x] `ge`
- [x] `lt`
- [x] `le`
- [x] `pr`
- [x] `sw`
- [x] `ew`
- [x] `co`
