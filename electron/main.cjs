const { app, BrowserWindow, dialog, session } = require("electron");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const net = require("node:net");
const path = require("node:path");

const maxStartupOutputLength = 8_000;
let rProcess;
let shinyUrl;
let mainWindow;

function configureExcelSaveDialog() {
  session.defaultSession.on("will-download", (_event, item) => {
    if (path.extname(item.getFilename()).toLowerCase() !== ".xlsx") {
      return;
    }

    item.setSaveDialogOptions({
      title: "Save Excel report",
      defaultPath: path.join(app.getPath("documents"), item.getFilename()),
      filters: [{ name: "Excel Workbook", extensions: ["xlsx"] }],
    });
    item.once("done", (_event, state) => {
      if (state === "interrupted") {
        dialog.showErrorBox(
          "Excel report not saved",
          "The download was interrupted. Please generate the report again.",
        );
      }
    });
  });
}

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
      await rProcess.closePromise;
      const reason = rProcess.signalCode
        ? `signal ${rProcess.signalCode}`
        : `exit code ${rProcess.exitCode}`;
      const output = rProcess.startupOutput.trim();
      throw new Error(
        `The R process exited with ${reason} before the app was ready.` +
          (output ? `\n\nR startup output:\n${output}` : ""),
      );
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
  const systemRscript = "/usr/local/bin/Rscript";
  const rscript =
    process.env.RSCRIPT_PATH ||
    (process.platform === "darwin" && fs.existsSync(systemRscript)
      ? systemRscript
      : "Rscript");
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
      databasePath,
      attachmentsDirectory,
      String(port),
    ],
    {
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    },
  );
  rProcess.spawnError = null;
  rProcess.startupOutput = "";
  const appendStartupOutput = (chunk) => {
    rProcess.startupOutput = (rProcess.startupOutput + chunk.toString()).slice(
      -maxStartupOutputLength,
    );
  };
  rProcess.stdout.on("data", appendStartupOutput);
  rProcess.stderr.on("data", appendStartupOutput);
  rProcess.closePromise = new Promise((resolve) => {
    rProcess.once("close", resolve);
  });
  rProcess.on("error", (error) => {
    rProcess.spawnError = error;
  });

  shinyUrl = await waitForShiny(port);
  await openWindow();
}

async function openWindow() {
  mainWindow = new BrowserWindow({
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
  mainWindow.on("closed", () => {
    mainWindow = null;
  });
  await mainWindow.loadURL(shinyUrl);
}

app.whenReady().then(async () => {
  try {
    configureExcelSaveDialog();
    await startApp();
  } catch (error) {
    if (rProcess && rProcess.exitCode === null) {
      rProcess.kill();
    }
    dialog.showErrorBox(
      "Unable to start Halkhata",
      `${error.message}\n\nMake sure R and the halkhata package are installed. ` +
        "Make sure Rscript is on PATH, or set the RSCRIPT_PATH environment variable.",
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
