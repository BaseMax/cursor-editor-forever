# Cursor Editor Forever

A Bash script designed to reset the license of the Cursor editor, enabling extended use by updating telemetry IDs and modifying the AppImage to bypass license checks.

## Usage

### Prerequisites

To run the script, ensure the following tools are installed on your system:

- **Bash shell** (available by default on most Linux systems)
- **`uuidgen`** (used to generate unique IDs)
- **`jq`** (optional, but recommended for JSON manipulation in `storage.json`)
- **AppImage Tool** (ttps://github.com/AppImage/appimagetool/‍)

You can install these dependencies on Ubuntu or Debian-based systems with:

```bash
sudo apt-get install uuid-runtime jq
```

### Running the Script

Follow these steps to use the script:

Clone the repository:

```bash
git clone https://github.com/BaseMax/cursor-editor-forever.git
cd cursor-editor-forever
```

Make the script executable:

```bash
chmod +x cursor-editor-forever.sh
```

Run the script with your Cursor AppImage path:

```bash
./cursor-editor-forever.sh --appimage /path/to/cursor.AppImage
```

Replace `/path/to/cursor.AppImage` with the actual path to your Cursor AppImage file.

**Important: The script modifies the AppImage directly. It’s a good idea to back up your original AppImage before proceeding.**

### What the Script Does

- Updates telemetry IDs: Modifies the ~/.config/Cursor/User/globalStorage/storage.json file, resetting identifiers like machineId, macMachineId, devDeviceId, and sqmId.
- Alters AppImage contents: Extracts the AppImage, edits specific JavaScript files to disable license checks, and repacks it with the changes.
- Checks for Cursor process: Ensures the Cursor editor is not running during execution, pausing if necessary.

### Disclaimer

This script is intended for educational purposes only. It illustrates how software licensing mechanisms can be bypassed but should not be used to violate the Cursor editor’s licensing terms. The author is not liable for any misuse, damage, or legal issues arising from its use. Please respect the intellectual property rights of software developers and comply with all relevant licensing agreements.

## Contributing

We welcome contributions! If you’d like to report bugs or suggest enhancements, please follow these steps:

- Fork the repository to your GitHub account.
- Create a branch for your changes.
- Implement your modifications and test them thoroughly.
- Submit a pull request with a detailed explanation of your updates.
- Ensure your contributions align with the project’s coding style and include any necessary documentation.
