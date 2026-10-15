// Test/example host: caller supplies a compiled MoonBit ESM engine path.
// stdin/stdout contain PRIVATE metadata. Do not use with public logs.
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
const { exchange } = await import(pathToFileURL(process.argv[2]).href);
const cases = JSON.parse(readFileSync(0, 'utf8'));
process.stdout.write(JSON.stringify(cases.map(({ mode, input }) => JSON.parse(exchange(mode, input)))));
