# Examples

## Example policy settings

| Setting | Value |
|---|---|
| Trigger | Enrollment Complete, Recurring Check-in |
| Frequency | Once per computer |
| Script Parameter 4 | `MDS-DXB-` |
| Script Parameter 5 | `2` |
| Maintenance → Update Inventory | Off (the script runs it) |

## Example log: name changed

```
[2026-10-29 10:15:02] [INFO ] ===== Set Hostname from Jamf Computer ID v2.0.0 - started =====
[2026-10-29 10:15:02] [INFO ] Hostname prefix: MDS-DXB-
[2026-10-29 10:15:02] [INFO ] Minimum digits:  2
[2026-10-29 10:15:02] [INFO ] Running inventory update to obtain the Jamf Pro computer ID...
[2026-10-29 10:15:31] [INFO ] Jamf Pro computer ID: 7
[2026-10-29 10:15:31] [INFO ] Target hostname: MDS-DXB-07
[2026-10-29 10:15:31] [INFO ] ComputerName changed from 'Johns-MacBook-Pro' to 'MDS-DXB-07'.
[2026-10-29 10:15:31] [INFO ] HostName changed from '<not set>' to 'MDS-DXB-07'.
[2026-10-29 10:15:31] [INFO ] LocalHostName changed from 'Johns-MacBook-Pro' to 'MDS-DXB-07'.
[2026-10-29 10:15:31] [INFO ] Submitting updated inventory to Jamf Pro...
[2026-10-29 10:15:58] [INFO ] Inventory update completed.
[2026-10-29 10:15:58] [INFO ] ===== Completed successfully. Hostname: MDS-DXB-07 =====
```

## Example log: already correct

```
[2026-10-29 11:02:10] [INFO ] Target hostname: MDS-DXB-07
[2026-10-29 11:02:10] [INFO ] ComputerName is already set to MDS-DXB-07; no change needed.
[2026-10-29 11:02:10] [INFO ] HostName is already set to MDS-DXB-07; no change needed.
[2026-10-29 11:02:10] [INFO ] LocalHostName is already set to MDS-DXB-07; no change needed.
[2026-10-29 11:02:10] [INFO ] All name settings were already correct; skipping the final inventory update.
[2026-10-29 11:02:10] [INFO ] ===== Completed successfully. Hostname: MDS-DXB-07 =====
```
