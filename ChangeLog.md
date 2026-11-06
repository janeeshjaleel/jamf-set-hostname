# Changelog

## 2.0.0 — October 2026

- Prefix and minimum digits are now Jamf Pro script parameters (4 and 5)
- Sets ComputerName, HostName and LocalHostName
- Skips names that are already correct, and skips the final inventory update when nothing changed
- Input validation, 63-character name limit check and documented exit codes
- Timestamped logging
