#!/usr/bin/env node
/**
 * Downloads all 604 pages of Quran word data from the qurancdn API
 * and saves minimal JSON files for bundling with the worker.
 *
 * Usage: node scripts/download-quran-pages.mjs [--mushaf v1|v2|all]
 *
 * Output:
 *   src/data/quran-pages-v1.json + src/data/quran-index-v1.json  (mushaf=2, code_v1)
 *   src/data/quran-pages-v2.json + src/data/quran-index-v2.json  (mushaf=1, code_v2)
 */

import { writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const TOTAL_PAGES = 604;
const CONCURRENCY = 5;
const API_BASE = 'https://api.qurancdn.com/api/qdc/verses/by_page';

// Mushaf definitions: API mushaf id, code field name
const MUSHAFS = {
  v1: { id: 2, codeField: 'code_v1' },
  v2: { id: 1, codeField: 'code_v2' },
};

// Parse --mushaf arg
const args = process.argv.slice(2);
const mushafIdx = args.indexOf('--mushaf');
const mushafArg = mushafIdx >= 0 ? args[mushafIdx + 1] : 'all';
const targets = mushafArg === 'all' ? ['v1', 'v2'] : [mushafArg];

if (targets.some(t => !MUSHAFS[t])) {
  console.error('Invalid --mushaf value. Use v1, v2, or all.');
  process.exit(1);
}

async function fetchPage(pageNumber, mushafId, codeField) {
  const url = `${API_BASE}/${pageNumber}?words=true&fields=juz_number&word_fields=${codeField},line_number&per_page=all&mushaf=${mushafId}`;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      return data.verses.map(v => ({
        k: v.verse_key,
        j: v.juz_number,
        w: v.words.map(w => ({
          c: w[codeField],
          l: w.line_number,
        })),
      }));
    } catch (e) {
      console.error(`  Page ${pageNumber} attempt ${attempt + 1} failed: ${e.message}`);
      if (attempt < 2) await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
      else throw e;
    }
  }
}

async function downloadMushaf(version) {
  const { id, codeField } = MUSHAFS[version];
  const pagesOutput = resolve(__dirname, `../src/data/quran-pages-${version}.json`);
  const indexOutput = resolve(__dirname, `../src/data/quran-index-${version}.json`);

  console.log(`\nDownloading ${version} (mushaf=${id}, field=${codeField})...`);
  const pages = {};
  let done = 0;

  for (let i = 1; i <= TOTAL_PAGES; i += CONCURRENCY) {
    const batch = [];
    for (let j = i; j < i + CONCURRENCY && j <= TOTAL_PAGES; j++) {
      batch.push(j);
    }
    const results = await Promise.all(batch.map(p => fetchPage(p, id, codeField).then(data => ({ p, data }))));
    for (const { p, data } of results) {
      pages[p] = data;
    }
    done += batch.length;
    process.stdout.write(`\r  ${done}/${TOTAL_PAGES} pages downloaded`);
  }

  console.log('\n  Writing output...');
  const json = JSON.stringify(pages);
  writeFileSync(pagesOutput, json);
  const sizeMB = (Buffer.byteLength(json) / 1024 / 1024).toFixed(2);
  console.log(`  ${pagesOutput} (${sizeMB} MB)`);

  // Build surah-to-start-page index
  const surahStartPage = {};
  for (let p = 1; p <= TOTAL_PAGES; p++) {
    for (const v of pages[p]) {
      const surah = parseInt(v.k.split(':')[0]);
      if (!surahStartPage[surah]) surahStartPage[surah] = p;
    }
  }
  writeFileSync(indexOutput, JSON.stringify(surahStartPage));
  console.log(`  Surah index: ${indexOutput} (${Object.keys(surahStartPage).length} surahs)`);
}

async function main() {
  for (const version of targets) {
    await downloadMushaf(version);
  }
  console.log('\nDone!');
}

main().catch(e => { console.error(e); process.exit(1); });
