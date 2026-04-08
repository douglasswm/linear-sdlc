# Changelog

## v1.0.0 — 2026-04-08 — Plugin release

linear-sdlc is now a Claude Code plugin. This is the first tagged release.

### What it looks like
- **Namespaced invocation.** Skills are called as `/linear-sdlc:brainstorm`, `/linear-sdlc:implement`, `/linear-sdlc:debug`, `/linear-sdlc:checkpoint`, `/linear-sdlc:health`, `/linear-sdlc:create-tickets`, `/linear-sdlc:next`.
- **Plugin-based install.** `/plugin marketplace add git@github.com:douglasswm/linear-sdlc.git` then `/plugin install linear-sdlc@linear-sdlc`.
- **Secrets in the OS keychain.** Linear API key is collected at plugin enable time via `userConfig` and stored in macOS Keychain / Linux Secret Service / Windows Credential Manager. Never in plaintext config files.
- **Zero setup script.** The old `./setup` bash ritual is gone.

### Known untested
- **Marketplace install over SSH from a private repo.** Public repos are the supported path; private repos should work via `git@…` but haven't been verified.

### Pre-v1.0.0 history
The repo went through a skill-pack era (git clone + `./setup` + symlinks) before this release. That era had no tagged releases and no known external users. If you find a pre-v1.0.0 reference in this repo's git history, it belongs to that era and is not supported.
