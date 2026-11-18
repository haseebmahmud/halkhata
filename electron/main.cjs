const { app, BrowserWindow, dialog } = require("electron");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const net = require("node:net");
const path = require("node:path");

let rProcess;
let shinyUrl;

function findAvailablePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(port);
      });
    });
  });
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitForShiny(port) {
  const url = `http://127.0.0.1:${port}`;
  const deadline = Date.now() + 60_000;

  while (Date.now() < deadline) {
    if (rProcess.spawnError) {
      throw rProcess.spawnError;
    }
    if (rProcess.exitCode !== null || rProcess.signalCode !== null) {
      throw new Error("The R process exited before the app was ready.");
    }

    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(1_000) });
      if (response.ok) {
        return url;
      }
    } catch {
      // The server is not ready yet.
    }

    await delay(300);
  }

  throw new Error("Timed out while waiting for the Shiny server to start.");
}

async function startApp() {
  const projectRoot = path.resolve(__dirname, "..");
  const resourcesDirectory = app.isPackaged ? process.resourcesPath : projectRoot;
  const dataDirectory = app.getPath("userData");
  const databasePath = path.join(dataDirectory, "accounting.db");
  const attachmentsDirectory = path.join(dataDirectory, "attachments");
  const port = await findAvailablePort();
  const appDirectory = app.isPackaged
    ? path.join(resourcesDirectory, "shiny-app")
    : path.join(projectRoot, "inst", "shiny-app");
  const rLibrary = app.isPackaged
    ? path.join(resourcesDirectory, "R-library")
    : "";
  const macRuntime = app.isPackaged && process.platform === "darwin"
    ? JSON.parse(
        fs.readFileSync(path.join(resourcesDirectory, "r-runtime.json"), "utf8"),
      )
    : null;
  const bundledRHome = app.isPackaged
    ? macRuntime?.rHome || path.join(resourcesDirectory, "R")
    : null;
  const bundledRscript =
    process.platform === "darwin"
      ? macRuntime?.rscript
      : path.join(bundledRHome, "bin", "Rscript.exe");
  const rscript =
    process.env.RSCRIPT_PATH ||
    (app.isPackaged ? bundledRscript : "Rscript");
  const launcher = app.isPackaged
    ? path.join(resourcesDirectory, "start-shiny.R")
    : path.join(__dirname, "start-shiny.R");

  fs.mkdirSync(attachmentsDirectory, { recursive: true });

  rProcess = spawn(
    rscript,
    [
      "--vanilla",
      launcher,
      appDirectory,
      rLibrary,
      databasePath,
      attachmentsDirectory,
      String(port),
    ],
    {
      stdio: "inherit",
      env: {
        ...process.env,
        ...(bundledRHome
          ? {
              R_HOME: bundledRHome,
              R_LIBS_USER: rLibrary,
              PATH: [
                path.join(bundledRHome, "bin"),
                path.join(bundledRHome, "bin", "x64"),
                process.env.PATH || "",
              ].join(path.delimiter),
              ...(process.platform === "darwin"
                ? {
                    DYLD_LIBRARY_PATH: [
                      path.join(bundledRHome, "lib"),
                      process.env.DYLD_LIBRARY_PATH || "",
                    ]
                      .filter(Boolean)
                      .join(path.delimiter),
                  }
                : {}),
            }
          : {}),
      },
    },
  );
  rProcess.spawnError = null;
  rProcess.on("error", (error) => {
    rProcess.spawnError = error;
  });

  shinyUrl = await waitForShiny(port);
  await openWindow();
}

async function openWindow() {
  const window = new BrowserWindow({
    width: 1280,
    height: 900,
    minWidth: 900,
    minHeight: 650,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  await window.loadURL(shinyUrl);
}

app.whenReady().then(async () => {
  try {
    await startApp();
  } catch (error) {
    if (rProcess && rProcess.exitCode === null) {
      rProcess.kill();
    }
    dialog.showErrorBox(
      "Unable to start Halkhata",
      `${error.message}\n\nMake sure R and the halkhata package are installed. ` +
        "If Rscript is not on PATH, set the RSCRIPT_PATH environment variable.",
    );
    app.quit();
  }
});

app.on("before-quit", () => {
  if (rProcess && rProcess.exitCode === null) {
    rProcess.kill();
  }
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0 && shinyUrl) {
    openWindow().catch((error) => {
      dialog.showErrorBox("Unable to open Halkhata", error.message);
    });
  }
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
