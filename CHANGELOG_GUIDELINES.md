# Changelog Update Guidelines

To maintain a clear and consistent history of changes in this project, please follow these guidelines when updating the CHANGELOG:

## Format

- The CHANGELOG follows the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) standard.
- Use the following sections for entries:
    - Unreleased
    - Added
    - Changed
    - Deprecated
    - Removed
    - Fixed
    - Security

## Entry Details

- Include the date in the format `YYYY-MM-DD`.
- Provide a concise but descriptive summary of the change.
- Reference relevant issue or pull request numbers.

## Updating the CHANGELOG

1. **Every pull request that introduces a change must update the CHANGELOG.**
2. **Ensure the entry is under the correct section based on the type of change.**
3. **If multiple changes are made in a single pull request, each change should be listed separately.**

## Examples
## [Unreleased]

### Added
- Initial release

## [1.0.0] - YYYY-MM-DD
### Added
- Introduced a new module for VPC creation. [#23]
- Added support for multiple AWS regions. [#45]

### Changed
- Updated the AMI hardening script to include new security benchmarks. [#56]

### Fixed
- Fixed an issue where the SSH configuration script failed on Debian-based systems. [#67]

### Security
- Patched a vulnerability in the logging configuration that could allow unauthorized access. [#78]