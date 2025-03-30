#!/bin/bash

# Create directory for scripts
mkdir -p ~/router-restart
cd ~/router-restart

# Prompt the user for router details
read -p "Enter the router IP address (e.g., 192.168.1.1): " ROUTER_IP
read -p "Enter the router username: " USERNAME
read -sp "Enter the router password: " PASSWORD
echo

# Test connectivity to the router
echo "Checking router accessibility at http://$ROUTER_IP..."
if curl -s --head --request GET "http://$ROUTER_IP" | grep "200 OK" > /dev/null; then
    echo "Router is accessible. Proceeding with setup..."
else
    echo "Error: Unable to access router at http://$ROUTER_IP. Check the IP address and try again."
    exit 1
fi

# Install Node.js if not already installed
if ! command -v node &> /dev/null; then
    echo "Node.js not found!"
    echo "Updating packages..."

    # Update the packages
    sudo apt update

    # Ensuring we have all the packages we need to access the Nodesource repository
    echo "Installing prerequisites to install Node.js..."
    sudo apt install -y ca-certificates curl gnupg

    echo "Adding Nodesource repository..."
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt update

    echo "Installing Node.js..."
    sudo apt install -y nodejs
else
    echo "Node.js is already installed."
fi

# Install Chromium and required dependencies
echo "Installing Chromium and dependencies..."
sudo apt-get update
sudo apt-get install -y chromium-browser
# Additional dependencies that might be needed for Puppeteer on Raspberry Pi
sudo apt-get install -y libatk-bridge2.0-0 libgtk-3-0 libgbm1

# Initialize a new Node.js project if package.json doesn't exist
if [ ! -f package.json ]; then
    echo "Setting up Node.js project..."
    npm init -y
fi

# Install Puppeteer and date-fns if not already installed
if [ ! -d "node_modules" ]; then
    echo "Installing Puppeteer and other dependencies..."
    npm install puppeteer date-fns
else
    echo "Dependencies are already installed."
fi

# Create the router restart script
echo "Creating router restart script..."
cat > ~/router-restart/restart-HG8145V5.js << EOL
#!/usr/bin/env node

const puppeteer = require("puppeteer");
const fs = require("fs");
const path = require("path");
const { format } = require("date-fns");

// Router settings
const ROUTER_IP = "$ROUTER_IP";
const USERNAME = "$USERNAME";
const PASSWORD = "$PASSWORD";

// Log file path
const LOG_FILE = path.join(process.env.HOME, "router-restart/restart.log");

/**
 * Log a message to both console and log file
 * @param {string} message - The message to log
 * @param {string} level - Log level (info, error, etc.)
 */
function log(message, level = "INFO") {
  const timestamp = format(new Date(), "yyyy-MM-dd HH:mm:ss");
  const logMessage = \`\${timestamp} - \${level} - \${message}\`;

  console.log(logMessage);

  // Append to log file
  fs.appendFileSync(LOG_FILE, logMessage + "\\n");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Restart the Huawei HG8145V5 router using Puppeteer
 */
async function restartRouter() {
  log("=== Starting scheduled router restart ===");

  let browser;

  try {
    // Launch Puppeteer in headless mode
    log("Launching browser");
    browser = await puppeteer.launch({
      headless: true,
      executablePath: "/usr/bin/chromium-browser",
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    const page = await browser.newPage();

    // Set default timeout
    page.setDefaultTimeout(30000);

    // Navigate to router login page
    const url = \`http://\${ROUTER_IP}/\`;
    log(\`Navigating to \${url}\`);
    await page.goto(url, { waitUntil: "networkidle2" });

    // Wait for login form and enter credentials
    log("Entering login credentials");
    await page.waitForSelector("#txt_Username");
    await page.type("#txt_Username", USERNAME);
    await page.type("#txt_Password", PASSWORD);

    // Click login button and wait for navigation
    await Promise.all([page.click("#loginbutton"), page.waitForNavigation()]);

    log("Successfully logged in");

    const menuIframeElement = await page.waitForSelector("iframe#menuIframe");
    const menuIframe = await menuIframeElement.contentFrame();

    if (menuIframe) {
      await menuIframe.waitForSelector("#RestartIcon");

      // Click on Red reset button and wait for Restart button to appear
      log("Clicking Red Reset button on router");
      await menuIframe.click("#RestartIcon");
      const routerIframeElement = await menuIframe.waitForSelector(
        "iframe#routermngtpageSrc"
      );
      const routerIframe = await routerIframeElement.contentFrame();

      if (routerIframe) {
        // Handle confirmation dialog
        page.on("dialog", async (dialog) => {
          log("Accepting confirmation dialog");
          await dialog.accept();
        });

        await routerIframe.waitForSelector("#btnReboot");
        // Click on Restart button
        log("Clicking Restart button");
        await routerIframe.click("#btnReboot");

        // Wait briefly to ensure the reboot command is sent
        await sleep(5000);
      } else {
        log("Unable to load routerIframe!");
      }

      log("Reboot command sent successfully");
    } else {
      log("Unable to load menuIframe!");
    }
    await browser.close();
    log("=== Scheduled router restart completed successfully ===\\n");
  } catch (error) {
    log(\`Error during router restart: \${error.message}\`, "ERROR");

    if (browser) {
      await browser.close();
    }

    log("=== Scheduled router restart process failed ===", "ERROR");
  }
}

// Execute the main function
restartRouter();
EOL

# Make the script executable
chmod +x ~/router-restart/restart-HG8145V5.js

# Confirm before creating the cron job
read -p "Do you want to create a cron job to restart the router at 3:00 AM daily? (y/n): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    # Create a cron job entry
    echo "Setting up cron job..."
    (crontab -l 2>/dev/null | grep -v "router-restart/restart-HG8145V5.js"; echo "0 3 * * * cd ~/router-restart && /usr/bin/node restart-HG8145V5.js") | crontab -

    echo "Setup completed. The router will restart daily at 3:00 AM."
else
    echo "Cron job setup skipped. You can manually run the script using:"
    echo "cd ~/router-restart && /usr/bin/node restart-HG8145V5.js"
fi

echo "You only need to run this setup script once. The cron job (if created) will execute the restart script without reinstalling dependencies."
