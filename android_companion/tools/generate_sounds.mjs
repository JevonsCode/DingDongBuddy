// Regenerates the two bundled notification sounds as 16-bit mono WAV files.
// Usage: node android_companion/tools/generate_sounds.mjs
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const sampleRate = 44100;
const outputDirectory = join(
  dirname(fileURLToPath(import.meta.url)),
  "../app/src/main/res/raw",
);

// Each note: [frequency Hz, start s, duration s, peak 0..1].
const sounds = {
  // A soft two-note rising chime: "done".
  agent_completion: [
    [1046.5, 0.0, 0.32, 0.55],
    [1568.0, 0.16, 0.5, 0.5],
  ],
  // Two pairs of brighter, repeated beeps: "your turn".
  agent_attention: [
    [880.0, 0.0, 0.14, 0.7],
    [1174.7, 0.16, 0.18, 0.7],
    [880.0, 0.5, 0.14, 0.7],
    [1174.7, 0.66, 0.3, 0.7],
  ],
};

for (const [name, notes] of Object.entries(sounds)) {
  const length = Math.max(...notes.map(([, start, duration]) => start + duration)) + 0.05;
  const samples = new Float32Array(Math.ceil(length * sampleRate));
  for (const [frequency, start, duration, peak] of notes) {
    const first = Math.floor(start * sampleRate);
    const count = Math.floor(duration * sampleRate);
    for (let index = 0; index < count; index += 1) {
      const t = index / sampleRate;
      const attack = Math.min(1, t / 0.006);
      const decay = Math.exp((-4.5 * t) / duration);
      // A quiet octave partial makes the tone less clinical than a pure sine.
      const tone =
        Math.sin(2 * Math.PI * frequency * t) +
        0.25 * Math.sin(2 * Math.PI * frequency * 2 * t);
      samples[first + index] += (peak * attack * decay * tone) / 1.25;
    }
  }
  writeFileSync(join(outputDirectory, `${name}.wav`), wav(samples));
}

function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((value, index) => {
    const clamped = Math.max(-1, Math.min(1, value));
    data.writeInt16LE(Math.round(clamped * 32767), index * 2);
  });
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(sampleRate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}
