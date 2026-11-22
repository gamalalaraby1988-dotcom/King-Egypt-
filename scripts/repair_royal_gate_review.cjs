const fs = require("node:fs");
const path = require("node:path");

const input = "assets/models/royal_gate.glb";
const output = "artifacts/royal-gate-review/royal_gate_repaired.glb";
const source = fs.readFileSync(input);
if (source.toString("ascii", 0, 4) !== "glTF") throw new Error("Input is not a GLB file.");

const version = source.readUInt32LE(4);
if (version !== 2) throw new Error(`Unsupported GLB version: ${version}`);
const declaredLength = source.readUInt32LE(8);
if (declaredLength !== source.length) throw new Error("GLB header length mismatch.");

let offset = 12;
let json = null;
let bin = null;
while (offset < source.length) {
  const length = source.readUInt32LE(offset);
  const type = source.readUInt32LE(offset + 4);
  const chunk = source.subarray(offset + 8, offset + 8 + length);
  if (type === 0x4e4f534a) json = JSON.parse(chunk.toString("utf8").trim());
  else if (type === 0x004e4942) bin = Buffer.from(chunk);
  offset += 8 + length;
}
if (!json || !bin) throw new Error("GLB JSON or BIN chunk is missing.");

const bufferLength = json.buffers?.[0]?.byteLength;
if (!Number.isInteger(bufferLength) || bufferLength > bin.length) {
  throw new Error("Invalid GLB buffer byteLength.");
}
bin = bin.subarray(0, bufferLength);

const normalAccessors = new Set();
for (const mesh of json.meshes ?? []) {
  for (const primitive of mesh.primitives ?? []) {
    if (Number.isInteger(primitive.attributes?.NORMAL)) {
      normalAccessors.add(primitive.attributes.NORMAL);
    }
  }
}
if (normalAccessors.size === 0) throw new Error("No NORMAL accessors found.");

const componentInfo = {
  5120: { size: 1, read: "getInt8" },
  5121: { size: 1, read: "getUint8" },
  5122: { size: 2, read: "getInt16" },
  5123: { size: 2, read: "getUint16" },
  5125: { size: 4, read: "getUint32" },
  5126: { size: 4, read: "getFloat32" }
};
let normalizedVectors = 0;

for (const [indexText, accessor] of (json.accessors ?? []).entries()) {
  const index = Number(indexText);
  if (accessor.type !== "VEC3" || accessor.bufferView === undefined) continue;
  const info = componentInfo[accessor.componentType];
  if (!info) throw new Error(`Unsupported accessor component type at index ${index}.`);
  const view = json.bufferViews[accessor.bufferView];
  if (!view || (view.buffer ?? 0) !== 0) throw new Error(`Invalid bufferView for accessor ${index}.`);
  const stride = view.byteStride ?? info.size * 3;
  const start = (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0);
  const data = new DataView(bin.buffer, bin.byteOffset, bin.byteLength);
  const getter = info.read;
  const littleEndian = info.size > 1;
  const values = [];
  const minima = [Infinity, Infinity, Infinity];
  const maxima = [-Infinity, -Infinity, -Infinity];

  for (let i = 0; i < accessor.count; i++) {
    const p = start + i * stride;
    const v = [0, 1, 2].map(c => data[getter](p + c * info.size, littleEndian));
    if (normalAccessors.has(index)) {
      if (accessor.componentType !== 5126) {
        throw new Error(`NORMAL accessor ${index} is not FLOAT; refusing unsafe conversion.`);
      }
      const magnitude = Math.hypot(v[0], v[1], v[2]);
      if (!Number.isFinite(magnitude) || magnitude < 1e-12) {
        throw new Error(`NORMAL accessor ${index} contains a zero or invalid vector at ${i}.`);
      }
      const normalized = v.map(x => x / magnitude);
      for (let c = 0; c < 3; c++) data.setFloat32(p + c * 4, normalized[c], true);
      normalizedVectors++;
      for (let c = 0; c < 3; c++) v[c] = normalized[c];
    }
    for (let c = 0; c < 3; c++) {
      if (!Number.isFinite(v[c])) throw new Error(`Non-finite value in accessor ${index}.`);
      minima[c] = Math.min(minima[c], v[c]);
      maxima[c] = Math.max(maxima[c], v[c]);
    }
    values.push(v);
  }
  if (accessor.count > 0) {
    accessor.min = minima;
    accessor.max = maxima;
  }
}

if (normalizedVectors === 0) throw new Error("No normal vectors were normalized.");
json.buffers[0].byteLength = bin.length;

const jsonBytes = Buffer.from(JSON.stringify(json), "utf8");
const jsonPaddedLength = Math.ceil(jsonBytes.length / 4) * 4;
const binPaddedLength = Math.ceil(bin.length / 4) * 4;
const jsonChunk = Buffer.alloc(jsonPaddedLength, 0x20);
jsonBytes.copy(jsonChunk);
const binChunk = Buffer.alloc(binPaddedLength);
bin.copy(binChunk);

const totalLength = 12 + 8 + jsonChunk.length + 8 + binChunk.length;
const glb = Buffer.alloc(totalLength);
glb.write("glTF", 0, 4, "ascii");
glb.writeUInt32LE(2, 4);
glb.writeUInt32LE(totalLength, 8);
glb.writeUInt32LE(jsonChunk.length, 12);
glb.writeUInt32LE(0x4e4f534a, 16);
jsonChunk.copy(glb, 20);
const binHeader = 20 + jsonChunk.length;
glb.writeUInt32LE(binChunk.length, binHeader);
glb.writeUInt32LE(0x004e4942, binHeader + 4);
binChunk.copy(glb, binHeader + 8);

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, glb);
console.log(`Created isolated review copy: ${output}`);
console.log(`Normalized ${normalizedVectors} normal vectors and recalculated VEC3 accessor bounds.`);
console.log(`Preserved source file unchanged: ${input}`);
