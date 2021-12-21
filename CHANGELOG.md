# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.16.3-rc.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.16.3...v0.16.3-rc.0) (2021-12-21)




### Improvements:

* policy breakdowns

* use latest ash to have custom exceptions

* update to latest ash for bug fix

* add some simple tests that use exprs

* initial `expr/1` support for policies

## [v0.16.3](https://github.com/ash-project/ash_policy_authorizer/compare/v0.16.2...v0.16.3) (2021-10-24)




### Bug Fixes:

* undo unnecessary change

* honor strict access type when generating filters

### Improvements:

* breaking change, forbid on no applicable condition

## [v0.16.2](https://github.com/ash-project/ash_policy_authorizer/compare/v0.16.1-rc1...v0.16.2) (2021-07-02)




### Improvements:

* upgrade to latest ash

## [v0.16.1-rc1](https://github.com/ash-project/ash_policy_authorizer/compare/v0.16.1-rc0...v0.16.1-rc1) (2021-06-21)




### Bug Fixes:

* empty filter w/ empty checks is reachable

## [v0.16.1-rc0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.16.0...v0.16.1-rc0) (2021-06-15)




### Bug Fixes:

* various policy fixes

### Improvements:

* call `error_messages/3`

## [v0.16.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.15.0...v0.16.0) (2021-03-07)




### Features:

* add `selecting` simple check

### Bug Fixes:

* some check types broke policies

## [v0.15.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.14.6...v0.15.0) (2021-02-23)




### Features:

* customize the `reject` of filter checks

### Bug Fixes:

* related_to_actor_via/1 now properly negates

## [v0.14.6](https://github.com/ash-project/ash_policy_authorizer/compare/v0.14.5...v0.14.6) (2021-02-23)




### Bug Fixes:

* update ash version dependency

## [v0.14.5](https://github.com/ash-project/ash_policy_authorizer/compare/v0.14.4...v0.14.5) (2021-02-23)




### Improvements:

* update to latest ash

## [v0.14.4](https://github.com/ash-project/ash_policy_authorizer/compare/v0.14.3...v0.14.4) (2021-01-28)




### Improvements:

* support errors in checks

## [v0.14.3](https://github.com/ash-project/ash_policy_authorizer/compare/v0.14.2...v0.14.3) (2021-01-27)




### Bug Fixes:

* less strict validation of check modules

## [v0.14.2](https://github.com/ash-project/ash_policy_authorizer/compare/v0.14.1...v0.14.2) (2021-01-22)




### Improvements:

* support latest ash

## [v0.14.1](https://github.com/ash-project/ash_policy_authorizer/compare/v0.14.0...v0.14.1) (2020-12-27)




## [v0.14.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.13.0...v0.14.0) (2020-10-10)




### Features:

* support latest ash

## [v0.13.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.12.0...v0.13.0) (2020-09-20)




### Features:

* make bypass policies a top level builder

## [v0.12.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.11.0...v0.12.0) (2020-09-02)




### Features:

* policy level access types (#14)

* add actor_attribute_equals

* add relating_to_actor

* add changing_relationships

* add `bypass?` policies

* support policy specific access types (#12)

### Bug Fixes:

* remove actor_matches

## [v0.11.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.10.0...v0.11.0) (2020-08-26)




### Features:

* richer conditions, name -> description

## [v0.10.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.9.0...v0.10.0) (2020-08-18)




### Features:

* update to latest ash

* support logging policies when verbose mode

### Bug Fixes:

* require description on actor_matches fix mod

* don't filter on facts we already know

## [v0.9.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.8.1...v0.9.0) (2020-08-18)




### Features:

* update to latest ash

## [v0.8.1](https://github.com/ash-project/ash_policy_authorizer/compare/v0.8.0...v0.8.1) (2020-08-17)




### Bug Fixes:

* use attribute in `attribute` built in check

* regenerate formatter

## [v0.8.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.7.0...v0.8.0) (2020-08-17)




### Features:

* refactor built in checks for flexibility

* multiple conditions per check

## [v0.7.0](https://github.com/ash-project/ash_policy_authorizer/compare/v0.6.0...v0.7.0) (2020-08-10)




### Features:

* update to lastest ash

## [v0.6.0](https://github.com/ash-project/ash_policy_authorizer/compare/0.5.0...v0.6.0) (2020-07-24)




### Features:

* update to latest ash

## [v0.5.0](https://github.com/ash-project/ash_policy_authorizer/compare/0.4.0...v0.5.0) (2020-07-23)




### Features:

* update to latest ash

## [v0.4.0](https://github.com/ash-project/ash_policy_authorizer/compare/0.3.0...v0.4.0) (2020-06-29)




### Features:

* update to latest ash

## [v0.3.0](https://github.com/ash-project/ash_policy_authorizer/compare/0.2.0...v0.3.0) (2020-06-29)




### Features:

* upgrade to latest ash

## [v0.2.0](https://github.com/ash-project/ash_policy_authorizer/compare/0.1.6...v0.2.0) (2020-06-27)




### Features:

* update to latest ash

## [v0.1.6](https://github.com/ash-project/ash_policy_authorizer/compare/0.1.5...v0.1.6) (2020-06-21)




## [v0.1.5](https://github.com/ash-project/ash_policy_authorizer/compare/0.1.4...v0.1.5) (2020-06-21)




### Bug Fixes:

* update for new filter logic

## [v0.1.4](https://github.com/ash-project/ash_policy_authorizer/compare/0.1.3...v0.1.4) (2020-06-15)

New version release due to a CI error


## [v0.1.3](https://github.com/ash-project/ash_policy_authorizer/compare/0.1.2...v0.1.3) (2020-06-15)




### Bug Fixes:

* consider nested entities in ash.formatter

## [v0.1.2](https://github.com/ash-project/ash_policy_authorizer/compare/0.1.1...v0.1.2) (2020-06-15)




### Bug Fixes:

* update to ash 5.1/small fixes

## [v0.1.1](https://github.com/ash-project/ash_policy_authorizer/compare/0.1.0...v0.1.1) (2020-06-08)

Renamed from ash_policy_access to ash_policy_authorizer

## Begin Changelog
