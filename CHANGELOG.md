# Changelog

## [0.301.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.300.0...state_machines-activerecord/v0.301.0) (2026-11-15)


### Features

* allow direct state assignment by default; opt in with direct_assignment: :deny ([836f1b5](https://github.com/state-machines/state_machines-activerecord/commit/836f1b5b4160ef8ad4d149d56860eac57b9f672f))

## [0.300.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.200.0...state_machines-activerecord/v0.300.0) (2026-11-15)


### ⚠ BREAKING CHANGES

* make state changes event-only through the model ([#47](https://github.com/state-machines/state_machines-activerecord/issues/47))
* require state_machines and state_machines-activemodel >= 0.300.0
* ActiveRecord 8.0+ is now required.

### Features

* clear refusal reasons on reload and cover them through ActiveRecord ([d13c772](https://github.com/state-machines/state_machines-activerecord/commit/d13c7724b282297d7b07d7b445f5e39d0bfa156d))
* drop Rails 7.2 support ([010459a](https://github.com/state-machines/state_machines-activerecord/commit/010459ad0364b59733359771e130c5af1598fbbd))
* make state changes event-only through the model ([#47](https://github.com/state-machines/state_machines-activerecord/issues/47)) ([4b1a39d](https://github.com/state-machines/state_machines-activerecord/commit/4b1a39dd8ac834cc790ca521e687392ff90f2f76))
* require state_machines and state_machines-activemodel &gt;= 0.300.0 ([4186a5a](https://github.com/state-machines/state_machines-activerecord/commit/4186a5aa878714162d497d928d2711581ac90018))
* run tests with padded_cell on CRuby ([#141](https://github.com/state-machines/state_machines-activerecord/issues/141)) ([dfab384](https://github.com/state-machines/state_machines-activerecord/commit/dfab384a7430fd5a274d719ab615bc61cd5374ee))
* use the schema default as initial state when none is configured ([507e378](https://github.com/state-machines/state_machines-activerecord/commit/507e378bb92cc5fd89c3a84905cb8bc98be16df4)), closes [#73](https://github.com/state-machines/state_machines-activerecord/issues/73)


### Bug Fixes

* initialize transient state attributes on records loaded from the database ([5cc0212](https://github.com/state-machines/state_machines-activerecord/commit/5cc0212346d878a205a625574bcc0d78793e6866)), closes [#93](https://github.com/state-machines/state_machines-activerecord/issues/93)

## [0.200.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.103.0...state_machines-activerecord/v0.200.0) (2026-06-12)


### Features

* remove redundant run_scope override ([5aab883](https://github.com/state-machines/state_machines-activerecord/commit/5aab8838cd04e5c741244f938be0faedd4eb1d13))
* remove redundant run_scope override ([c8197a6](https://github.com/state-machines/state_machines-activerecord/commit/c8197a6f3cce8aeaacfe34e35ae2fe0757f48c71))
* support after_commit option on after_transition callbacks ([#138](https://github.com/state-machines/state_machines-activerecord/issues/138)) ([b717068](https://github.com/state-machines/state_machines-activerecord/commit/b717068531bc184b801549e2b959a8a1248b0b89)), closes [#112](https://github.com/state-machines/state_machines-activerecord/issues/112)


### Bug Fixes

* add opt-out for integer state attribute conversion ([4f0596b](https://github.com/state-machines/state_machines-activerecord/commit/4f0596bc6a72dcd83ff46948a80812f9e60604ea))
* handle auto-indexed integer column defaults ([#137](https://github.com/state-machines/state_machines-activerecord/issues/137)) ([b839a99](https://github.com/state-machines/state_machines-activerecord/commit/b839a990c3c554d3b634b935412597292823fba2))
* re-register integer attribute type when a machine is cloned for a subclass ([#136](https://github.com/state-machines/state_machines-activerecord/issues/136)) ([e903f7b](https://github.com/state-machines/state_machines-activerecord/commit/e903f7b1bba3cb8ce563576f19171c8a9170992a))

## [0.103.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.102.0...state_machines-activerecord/v0.103.0) (2026-03-23)


### Features

* support integer columns for state machine attributes ([452edec](https://github.com/state-machines/state_machines-activerecord/commit/452edec8d23e7f9d5546e95df8c2b3ab237c5b70))

## [0.102.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.100.0...state_machines-activerecord/v0.102.0) (2026-03-22)


### Features

* Add Rails enum integration with automatic conflict resolution ([#122](https://github.com/state-machines/state_machines-activerecord/issues/122)) ([08c7650](https://github.com/state-machines/state_machines-activerecord/commit/08c765029c02cd9c83768172279ee8a78b641f7e))
* transparent integer column support via custom AR attribute type ([6efa970](https://github.com/state-machines/state_machines-activerecord/commit/6efa970badf3ae2685042f1a4d752192aa2f74b6))


### Bug Fixes

* bump state_machines-activemodel to &gt;= 0.102.0 ([2f99c90](https://github.com/state-machines/state_machines-activerecord/commit/2f99c90e9f4f6ef158b0e195b930d9eb3167bb66))
* bump state_machines-activemodel to 0.101.0 and test Rails 8.1.0 ([#128](https://github.com/state-machines/state_machines-activerecord/issues/128)) ([8794d30](https://github.com/state-machines/state_machines-activerecord/commit/8794d30cd0abee26b9b0f6d4eabd5cb95f409c59))
* remove bump-patch-for-minor-pre-major ([215ccb2](https://github.com/state-machines/state_machines-activerecord/commit/215ccb271e63eeaa46de640b3eb001dc69747d8e))

## [0.100.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.100.0...state_machines-activerecord/v0.100.0) (2025-07-17)


### Features

* Add Rails enum integration with automatic conflict resolution ([#122](https://github.com/state-machines/state_machines-activerecord/issues/122)) ([08c7650](https://github.com/state-machines/state_machines-activerecord/commit/08c765029c02cd9c83768172279ee8a78b641f7e))

## [0.100.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.40.0...state_machines-activerecord/v0.100.0) (2025-07-17)


### Bug Fixes

* prevent fiber deadlocks with Ruby 3.4+ and Rails 8 ([#123](https://github.com/state-machines/state_machines-activerecord/issues/123)) ([507bdf0](https://github.com/state-machines/state_machines-activerecord/commit/507bdf0064a9e2fdd97f8915d40a7c961b6e884b))

## [0.40.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.31.0...state_machines-activerecord/v0.40.0) (2025-06-30)


### Features

* Drop Rails 7.1 support and require Rails 7.2+ ([#120](https://github.com/state-machines/state_machines-activerecord/issues/120)) ([e3df786](https://github.com/state-machines/state_machines-activerecord/commit/e3df786d27ff58937c705d9a5ee54ba6c2e26394)), closes [#57](https://github.com/state-machines/state_machines-activerecord/issues/57)

## [0.31.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord/v0.10.0...state_machines-activerecord/v0.31.0) (2025-06-30)


### Features

* Add transparent scope support (cherry-pick PR [#98](https://github.com/state-machines/state_machines-activerecord/issues/98)) ([5eef308](https://github.com/state-machines/state_machines-activerecord/commit/5eef30895e75840d0817166f1c36969f472ecaa0))


### Bug Fixes

* update I18n lambdas and apply RuboCop corrections ([#117](https://github.com/state-machines/state_machines-activerecord/issues/117)) ([4b739d4](https://github.com/state-machines/state_machines-activerecord/commit/4b739d4b69ebbef581ee6086457267fcf86bd922))

## [0.10.0](https://github.com/state-machines/state_machines-activerecord/compare/state_machines-activerecord-v0.9.0...state_machines-activerecord/v0.10.0) (2025-06-12)


### Features

* drop support for legacy version ([58a29a5](https://github.com/state-machines/state_machines-activerecord/commit/58a29a5dba93496e48ffda34563d2ac59f446bc0))


### Bug Fixes

* prepare to release 0.10.0 ([#115](https://github.com/state-machines/state_machines-activerecord/issues/115)) ([f9f89a4](https://github.com/state-machines/state_machines-activerecord/commit/f9f89a49507bc6bc5de125c4ddff54d0cc43f362))
* readme fix and release ([474cdd4](https://github.com/state-machines/state_machines-activerecord/commit/474cdd406a98fd3004f00b4ebd677ea882ea4182))
