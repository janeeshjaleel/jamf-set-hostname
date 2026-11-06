# Set Hostname from Jamf Pro Computer ID

A Jamf Pro script for macOS that names each Mac using a prefix you choose followed by its **Jamf Pro computer ID**, then submits updated inventory so the new name shows up in Jamf Pro.

| Computer ID | Prefix `MDS-DXB-`, 2 digits | Prefix `MDS-DXB-`, 4 digits |
|---|---|---|
| 7 | `MDS-DXB-07` | `MDS-DXB-0007` |
| 42 | `MDS-DXB-42` | `MDS-DXB-0042` |
| 1234 | `MDS-DXB-1234` | `MDS-DXB-1234` |

IDs are padded to the minimum number of digits and are **never truncated**.

## Features

- Sets all three macOS names: **ComputerName**, **HostName** and **LocalHostName**
- Prefix and padding are set with **Jamf Pro script parameters**, so one script works for every site
- **Idempotent**: names that are already correct are left alone, and the final inventory update is skipped if nothing changed
- Validates every input and stops **before** changing anything if the computer ID can't be read
- Timestamped log output in the Jamf policy log and clear, documented exit codes

## How it works

The script runs these steps in order and stops at the first problem:

1. **Checks it is running as root.** It exits with code 1 if not.
2. **Validates the parameters.** It trims spaces from Parameter 4 and Parameter 5. The prefix is required, may use only letters, numbers and hyphens, and must not start with a hyphen. Minimum digits defaults to 2 and must be between 1 and 10.
3. **Checks the Jamf binary exists** at `/usr/local/bin/jamf`.
4. **Gets the computer ID.** It runs `jamf recon` and reads the number between the `<computer_id>` tags in the output. If it can't find exactly one valid number greater than zero, it stops without renaming anything.
5. **Builds the new name.** It pads the ID with leading zeros to the minimum digits (7 becomes `07`) and adds the prefix. If the result is over 63 characters, it stops.
6. **Sets the names.** For ComputerName, HostName and LocalHostName, it reads the current value with `scutil --get`, skips any that already match, and sets the rest with `scutil --set`.
7. **Updates inventory.** If anything changed, it runs `jamf recon` again so Jamf Pro shows the new name. If nothing changed, it skips this step.

Every step writes a timestamped line to the Jamf policy log.

## Requirements

- macOS, enrolled in Jamf Pro
- Jamf binary at `/usr/local/bin/jamf`
- Runs as root (Jamf policies do this by default)
- No API credentials needed: the computer ID is read from `jamf recon` output

## Setup in Jamf Pro

1. **Settings → Computer Management → Scripts → New**
2. **General**: name it `Set Hostname from Jamf ID`
3. **Script**: paste the contents of [`set-hostname-from-jamf-id.sh`](set-hostname-from-jamf-id.sh)
4. **Options → Parameter Labels**:
   - Parameter 4: `Hostname prefix (e.g. MDS-DXB-)`
   - Parameter 5: `Minimum digits (default 2)`
5. Save.

### Create the policy

1. **Computers → Policies → New**
2. Add the script under **Scripts** and fill in Parameter 4 (and Parameter 5 if you want something other than 2).
3. Set the trigger (for example **Enrollment Complete** or **Recurring Check-in**) and frequency (**Once per computer** is typical).
4. Under **Maintenance**, leave **Update Inventory** unticked. The script already submits inventory after renaming.
5. Scope and save.

See [`Examples/`](Examples) for sample policy settings and log output.

## Parameters

| Parameter | Required | Description | Example |
|---|---|---|---|
| 4 | Yes | Hostname prefix. Letters, numbers and hyphens only; must not start with a hyphen. End it with a hyphen to separate it from the number. | `MDS-DXB-` |
| 5 | No | Minimum number of digits for the ID, 1–10. Default `2`. | `4` |

The full name must be 63 characters or fewer (the macOS LocalHostName limit).

## Testing locally

```bash
sudo ./set-hostname-from-jamf-id.sh "" "" "" "MDS-DXB-" "2"
```

Parameters 1–3 are reserved by Jamf, so pass empty strings for them.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success, or the hostname was already correct |
| 1 | Not run as root |
| 2 | Invalid or missing parameter (including a name that is too long) |
| 3 | Jamf binary not found |
| 4 | Inventory update failed or the computer ID could not be read (nothing changed) |
| 5 | Failed to set one of the names |
| 6 | Names changed, but the final inventory update failed |

## Disclaimer

This script is provided **"AS IS"** without warranty of any kind. Test it on a small group of Macs before scoping it widely. You use it at your own risk. See [LICENSE](LICENSE).

## Author

**Janeesh Jaleel**
