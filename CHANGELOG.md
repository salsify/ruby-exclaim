# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

## Unreleased

## 0.1.1 - 2024-11-18
### Fixed
- Fix various issues related to path segments that appear to be numbers.

## 0.1.0 - 2021-05-06
### Added
- Ability to disable all HTML escaping by setting the `should_escape_html` flag to `false` when instantiating
  `Exclaim::Ui`, e.g. `Exclaim::Ui.new(implementation_map: my_implementation_map, should_escape_html: false)`

## 0.0.0 - 2021-02-12
### Added
- Initial version
- When ready for release, bump `version.rb` to allow the release automation described in the README
  to detect the change. Note: this requires at least 1 commit to the default branch with this
  initial version.
