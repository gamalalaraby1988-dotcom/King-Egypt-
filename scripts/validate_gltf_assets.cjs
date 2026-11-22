const fs = require("node:fs");
const path = require("node:path");
const validator = require("gltf-validator");

const root = process.cwd();
const assetRoot = path.join(root, "assets");
const reportRoot = path.join(root, "artifacts", "gltf-validation");
const extensions = new Set([".glb", ".gltf"]);
const assets = [];

function walk(directory) {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(fullPath);
    else if (extensions.has(path.extname(entry.name).toLowerCase())) assets.push(fullPath);
  }
}

async function main() {
  walk(assetRoot);
  fs.mkdirSync(reportRoot, { recursive: true });
  if (assets.length === 0) {
    console.log("No GLB/glTF assets found; validation skipped.");
    return;
  }

  let errorCount = 0;
  for (const filename of assets.sort()) {
    const relativePath = path.relative(root, filename).split(path.sep).join("/");
    const bytes = new Uint8Array(fs.readFileSync(filename));
    const format = path.extname(filename).toLowerCase() === ".glb" ? "glb" : "gltf";
    const report = await validator.validateBytes(bytes, {
      uri: relativePath,
      format,
      writeTimestamp: false,
      maxIssues: 0
    });

    const errors = (report.issues?.messages ?? []).filter((issue) => issue.severity === 0);
    errorCount += errors.length;
    const reportName = relativePath.replaceAll("/", "__") + ".report.json";
    fs.writeFileSync(
      path.join(reportRoot, reportName),
      JSON.stringify({ asset: relativePath, report }, null, 2) + "\n"
    );
    console.log(
      `${relativePath}: ${errors.length} error(s), ${report.issues?.numWarnings ?? 0} warning(s), ${report.issues?.numInfos ?? 0} info(s)`
    );
  }

  console.log(`Validated ${assets.length} glTF asset(s); ${errorCount} error(s).`);
  if (errorCount > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error("glTF validation could not complete:", error);
  process.exitCode = 1;
});
