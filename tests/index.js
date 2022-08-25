const assert = require("assert");
const path = require("path");
const fs = require("fs/promises");
const Module = require("../dist/tesseract");

before(async function () {
  const outPath = path.join(__dirname, "out");
  await fs.mkdir(outPath, { recursive: true });
  const tessdataPath = path.join(outPath, "tessdata");
  await fs.cp(path.join(__dirname, "../dist/tessdata"), tessdataPath, {
    recursive: true,
  });
  await fs.cp(
    path.join(__dirname, "assets/eng.traineddata"),
    path.join(tessdataPath, "eng.traineddata"),
    {
      recursive: true,
    }
  );
});

describe("all", function () {
  it("should render eps to png", async function () {
    this.timeout(10000);
    const exitStatus = await callMain([
      "--tessdata-dir",
      "out/tessdata",
      "assets/sample.jpg",
      "out/sample",
      "-l",
      "eng",
      "pdf",
    ]);
    assert.equal(exitStatus, 0);
  });

  // Ensure this doesn't call `process.exit`
  it("should exit properly on error", async function () {
    const exitStatus = await callMain(["unknown-subcommand"]);
    assert.equal(exitStatus, 1);
  });
});

async function callMain(args) {
  const mod = await Module();
  const working = "/working";
  mod.FS.mkdir(working);
  mod.FS.mount(mod.NODEFS, { root: __dirname }, working);
  mod.FS.chdir(working);
  return mod.callMain(args);
}
