// This versioned adapter uses only the pinned Renovate installation's bundled presets.
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
const [installation, configFile, output] = process.argv.slice(2);
const { resolveConfigPresets } = await import(pathToFileURL(`${installation}/dist/config/presets/index.js`).href);
const config = JSON.parse(readFileSync(configFile, 'utf8'));
const resolved = await resolveConfigPresets(config);
writeFileSync(output, `${JSON.stringify(resolved)}\n`);
