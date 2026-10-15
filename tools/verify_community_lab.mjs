// Node + DOM contract tests. This is not a rendered-browser or CSP-enforcement
// test. No browser, listener, network client or remote content is used here.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const root=path.resolve(process.argv[2]??path.join(repo,'tmp/community-lab'));
const require=createRequire(path.join(repo,'web/package.json'));
const {parseHTML}=require('linkedom');
const sha=(data)=>createHash('sha256').update(data).digest('hex');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const build=JSON.parse(fs.readFileSync(path.join(root,'build.json'),'utf8'));
assert.equal(sha(html),build.html_sha256);
assert.equal(sha(fs.readFileSync(path.join(root,'engine.mjs'))),build.engine_sha256);
for(const [name,digest] of Object.entries(build.source_files_sha256)) assert.equal(sha(fs.readFileSync(path.join(repo,name))),digest,`stale build: ${name}`);
const script=html.match(/<script type="module">([\s\S]*?)<\/script>/)[1];
const cspHash=createHash('sha256').update(script).digest('base64');
assert.ok(html.includes(`script-src 'sha256-${cspHash}'`));
assert.ok(html.includes("connect-src 'none'"));
assert.equal((html.match(/<script/gi)??[]).length,1);
assert.ok(!/<(?:script|link|img|iframe)[^>]+(?:src|href)\s*=\s*["']https?:/i.test(html));
assert.ok(!/\b(?:fetch|XMLHttpRequest|WebSocket|sendBeacon)\s*\(/.test(script));

const samples=JSON.parse(fs.readFileSync(path.join(root,'samples.json'),'utf8'));
const {analyze}=await import(pathToFileURL(path.join(root,'engine.mjs')).href);
const policy={version:2,mode:'strict',namespace:'offline-synthetic-lab',date_shift_days:30};
const invoke=(inputs= samples,p=policy)=>JSON.parse(analyze(JSON.stringify(inputs),JSON.stringify(p)));
const good=invoke();assert.equal(good.status,'passed');assert.equal(good.report.objects,2);assert.equal(good.report.references,1);
assert.ok(good.structures[0].rows.some(row=>row.path.includes('[0]/')));
assert.equal(good.release_authorized,false);
for(const [inputs,code] of [[[samples[0]],'MEDSEAL-E520'],[[samples[1],samples[1]],'MEDSEAL-E520'],[[samples[0],samples[1].slice(0,100)],'MEDSEAL-E101'],[[],'MEDSEAL-E501'],[Array(17).fill(''),'MEDSEAL-E501']]) {
  const result=invoke(inputs);assert.equal(result.status,'blocked');assert.equal(result.issue.code,code);
}
const rule={id:'lab-study-description',path:'dataset/00081030',priority:10};
const removed=invoke(samples,{...policy,path_rules:[{...rule,action:'remove'}]});
assert.equal(removed.status,'passed');
assert.equal(removed.report.decisions[0].find(d=>d.path==='dataset/0008,1030').action,'remove');
assert.equal(invoke(samples,{...policy,path_rules:[{...rule,action:'keep'}]}).issue.code,'MEDSEAL-E510');
const hostile=invoke(samples,{...policy,path_rules:[{...rule,action:'replace',value:'<img src=x onerror=CANARY()>SECRET'}]});
assert.equal(hostile.status,'passed');assert.ok(!JSON.stringify(hostile).includes('SECRET'));
for(const canary of ['SYNTHETIC^SOURCE','SYNTHETIC-ID','19700101','20240229','1.2.3.30','987654321']) assert.ok(!JSON.stringify(good).includes(canary));
assert.equal(JSON.parse(analyze('x'.repeat(2*1024*1024+1),'{}')).issue.code,'MEDSEAL-E501');
assert.equal(JSON.parse(analyze('[]','x'.repeat(16385))).issue.code,'MEDSEAL-E501');

const {window}=parseHTML(html);
const document=window.document;
// linkedom omits the select.value setter available in browser DOM. Implement
// only that standard selector behavior; record the shim in the evidence.
for(const node of document.querySelectorAll('select')) {
  Object.defineProperty(node,'value',{
    get(){return [...this.querySelectorAll('option')].find(o=>o.hasAttribute('selected'))?.getAttribute('value')??this.querySelector('option').getAttribute('value');},
    set(value){for(const option of this.querySelectorAll('option')) option.toggleAttribute('selected',option.getAttribute('value')===value);},
  });
}
const downloads=[];let blobId=0;
const context=vm.createContext({window:{addEventListener(){}},document,console,TextEncoder,TextDecoder,Blob,
  setTimeout:(f)=>{f();},URL:{createObjectURL(blob){downloads.push(blob);return `blob:test-${++blobId}`;},revokeObjectURL(){}},
});
vm.runInContext(script,context,{timeout:15000});
const $=id=>document.getElementById(id);
const event=(node,type)=>node.dispatchEvent(new window.Event(type));
assert.match($('status').textContent,/通过/);assert.equal($('objects').textContent,'2');
$('preset').value='remove';event($('preset'),'change');event($('run'),'click');
assert.match($('changes').textContent,/清空 → 移除/);
$('filter').value='0008,1030';event($('filter'),'input');assert.equal($('decision-rows').children.length,1);
assert.match($('decision-rows').textContent,/移除/);
$('scenario').value='unresolved';event($('scenario'),'change');event($('run'),'click');
assert.equal($('status').dataset.state,'blocked');assert.equal($('objects').textContent,'—');assert.match($('issue').textContent,/MEDSEAL-E520/);
$('scenario').value='linked';event($('scenario'),'change');$('preset').value='invalid';event($('preset'),'change');event($('run'),'click');
assert.match($('issue').textContent,/MEDSEAL-E510/);
$('preset').value='empty';event($('preset'),'change');event($('run'),'click');event($('export'),'click');
assert.equal(downloads.length,1);const exported=JSON.parse(await downloads[0].text());
assert.equal(exported.release_authorized,false);assert.equal(exported.objects,2);
assert.ok(!JSON.stringify(exported).includes('SYNTHETIC-ID'));
$('policy').value='<script>SECRET-CANARY</script>';event($('run'),'click');
assert.equal($('status').dataset.state,'blocked');assert.ok(!$('issue').textContent.includes('SECRET-CANARY'));
assert.equal(document.querySelectorAll('script').length,1);

const result={schema:1,status:'passed',source_base_commit:build.source_base_commit,
  html_sha256:build.html_sha256,engine_sha256:build.engine_sha256,
  checks:['actual-compiled-moonbit-core','valid-linked-collection','closed-reference-and-duplicate-rejection','malformed-object-rejection','policy-action-change','unsupported-policy-rejection','transport-and-policy-budgets','public-canary-boundary','inline-script-csp-hash','no-network-api-or-external-asset','dom-filter-and-state-events','public-json-export'],
  validation_kind:'Node runtime and linkedom event contracts',
  dom_shims:['HTMLSelectElement.value setter'],rendered_browser_verified:false,
  csp_enforcement_verified:false,release_authorized:false};
fs.writeFileSync(path.join(root,'acceptance.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result));
