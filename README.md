# hg8145v5_restart_schedule_script

A scheduled restart script for Huawei EchoLife HG8145V5 EPON Terminal that automatically restarts the router at 3 AM everyday to maintain optimal performance.

## Features

- Automated router restart using Puppeteer
- Configurable schedule (default: daily at 3:00 AM)
- Secure credential handling
- Detailed logging of restart operations
- Easy setup script with guided configuration

## Prerequisites

- Linux-based system (tested on Raspberry Pi)
- Node.js 20.x or later
- Chromium browser
- Internet connectivity to the router

## Installation

1. Clone this repository or download the setup script:
   ```bash
   git clone https://github.com/abhyuday-95/hg8145v5_restart_schedule_script.git
   cd hg8145v5_restart_schedule_script
   ```

2. Make the setup script executable:
   ```bash
   chmod +x router-restart-setup.sh
   ```

3. Run the setup script:
   ```bash
   sudo ./router-restart-setup.sh
   ```

4. Follow the prompts to enter:
   - Router IP address
   - Router username
   - Router password
   - Confirm if you want to set up automatic daily restart

The setup script will:
- Create necessary directories
- Install required dependencies (Node.js, Chromium, Puppeteer)
- Configure the restart script with your credentials
- Set up a cron job for automated execution (if requested)

## Manual Execution

To manually run the restart script:
```bash
cd ~/router-restart
/usr/bin/node restart-HG8145V5.js
```

## Logging

The script maintains a log file at `~/router-restart/restart.log` that contains:
- Timestamp of each restart attempt
- Success/failure status
- Detailed error messages (if any)

## Security Notes

- Credentials are stored in the script file. Ensure proper file permissions are set.
- The script runs in headless mode for security.

## Troubleshooting

If you encounter issues:
1. Test with sudo.
2. Check the log file for error messages
3. Verify router accessibility at the configured IP
4. Ensure all dependencies are properly installed
5. Check cron job status with `crontab -l`
