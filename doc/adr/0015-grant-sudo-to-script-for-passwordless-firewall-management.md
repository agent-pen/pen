# 15. grant-sudo-to-script-for-passwordless-firewall-management

Date: 2026-02-12

## Status

Accepted

## Context

Host machine firewall rules are configured (via `pf`) when starting and stopping sandboxes. Managing these rules requires root privileges. It adds friction to the user experience if a password is requested every time the sandbox is started or stopped.

`sudo` supports granting specific scripts sudoer privileges, so they can be executed without challenging the user for a password. 

## Decision

When `pen` is installed, we will grant sudo privileges to a dedicated script for manipulating firewall rules.

The script will offer a narrowed scope for `pf` operations against a specified `pf` anchor.

Write access to the script will be restricted to the `root` user, so additional operations are not added to the privileged script. 

## Consequences

User must enter a password when first installing `pen`. 

Uninstall script should remove sudoer privileges from script.