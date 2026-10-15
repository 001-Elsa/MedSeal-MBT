// Actual browser acceptance using exclusively synthetic/phantom test files.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
function isolatedRssKiB(){
 const rows=execFileSync('ps',['-axo','pid=,ppid=,rss='],{encoding:'utf8'}).trim().split('\n').map(x=>x.trim().split(/\s+/).map(Number));
 const ids=new Set([process.pid]);let changed=true;while(changed){changed=false;for(const [pid,ppid] of rows)if(ids.has(ppid)&&!ids.has(pid)){ids.add(pid);changed=true;}}
 return rows.filter(([pid])=>ids.has(pid)&&pid!==process.pid).reduce((n,x)=>n+x[2],0);
}
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(path.join(repo,'web/package.json'));
const {chromium}=require('playwright');
const root=path.resolve(process.argv[2]??path.join(repo,'tmp/community-lab'));
const samples=JSON.parse(fs.readFileSync(path.join(root,'samples.json'))).map(x=>Buffer.from(x,'hex'));
const browser=await chromium.launch({headless:true,...(process.env.MEDSEAL_CHROME?{executablePath:process.env.MEDSEAL_CHROME}:{})});
const checks=[],remote=[],errors=[];
let baselineRss=0,loadedRss=0;
const forbidden=['SYNTHETIC-ID','SYNTHETIC^SOURCE','20240229','1.2.3.30','PRIVATE-FILENAME-CANARY','987654321'];
try {
 const context=await browser.newContext({viewport:{width:1280,height:900},acceptDownloads:true});
 // Record reads/workers/storage in the tested page only. Keep actual browser
 // APIs for file reading and workers; track termination and transfer detachment.
 await context.addInitScript(()=>{
  const metrics={reads:0,created:0,terminated:0,detached:0,storage:0};window.privateMetrics=metrics;
  const originalRead=Blob.prototype.arrayBuffer;
  Blob.prototype.arrayBuffer=function(){metrics.reads++;return originalRead.call(this);};
  const OriginalWorker=window.Worker;
  window.Worker=class extends OriginalWorker {
   constructor(...args){super(...args);metrics.created++;}
   terminate(){metrics.terminated++;return super.terminate();}
   postMessage(message,transfer){super.postMessage(message,transfer);if(transfer?.length)metrics.detached+=transfer.filter(x=>x.byteLength===0).length;}
  };
  const originalSet=Storage.prototype.setItem;
  Storage.prototype.setItem=function(...args){metrics.storage++;return originalSet.apply(this,args);};
 });
 const page=await context.newPage();
 page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(/^https?:/.test(r.url()))remote.push(r.url());});
 await page.goto(pathToFileURL(path.join(root,'index.html')).href);
 await page.locator('#status[data-state="passed"]').waitFor();
 await page.locator('#mode').selectOption('private');
 assert.equal(await page.locator('#mode').inputValue(),'private');
 await page.locator('#private-panel').waitFor({state:'visible'});checks.push('native-mode-selection-and-labeled-controls');
 baselineRss=isolatedRssKiB();
 const fixtures=samples.map((buffer,i)=>({name:`PRIVATE-FILENAME-CANARY-${i}.dcm`,mimeType:'application/dicom',buffer}));
 const select=files=>page.locator('#private-files').setInputFiles(files);
 const inspect=async files=>{await select(files);await page.locator('#private-check').focus();await page.keyboard.press('Enter');};
 const passed=()=>page.waitForFunction(()=>document.getElementById('private-status').textContent.includes('只读检查通过'));
 const blocked=()=>page.waitForFunction(()=>/阻断|文件未读取/.test(document.getElementById('private-status').textContent));
 await inspect(fixtures);await passed();
 assert.equal(await page.locator('#private-object option').count(),2);
 assert.ok(await page.locator('#private-structures tr').count()>0);
 for(const value of forbidden)assert.ok(!(await page.locator('#private-panel').innerText()).includes(value));
 assert.equal(await page.locator('#private-values').isVisible(),false);
 assert.equal(await page.locator('#private-files').inputValue(),'');
 loadedRss=isolatedRssKiB();
 const metrics=await page.evaluate(()=>window.privateMetrics);assert.equal(metrics.reads,2);assert.equal(metrics.detached,2);
 checks.push('real-files-binary-transfer-readonly-MoonBit-and-default-hidden-values');
 const downloadP=page.waitForEvent('download');await page.locator('#private-export').click();const download=await downloadP;
 assert.equal(download.suggestedFilename(),'medseal-readonly-public.json');
 await download.saveAs(path.join(root,'private-public-summary.json'));
 const report=JSON.parse(fs.readFileSync(path.join(root,'private-public-summary.json')));
 assert.deepEqual(report,{schema:1,scope:'read-only-current-collection',status:'validated',objects:2,references:1,release_authorized:false});
 for(const value of forbidden)assert.ok(!JSON.stringify(report).includes(value));checks.push('anonymous-download-exact-allowlist-no-original-values-or-filenames');
 // A malicious-looking original PN is legal text, not markup. Keep the
 // exact existing value length so this is an independent byte mutation.
 const hostile=fixtures.map(f=>({...f,buffer:Buffer.from(f.buffer)}));
 for(const file of hostile){const n=file.buffer.indexOf(Buffer.from('SYNTHETIC^SOURCE'));assert.ok(n>=0);file.buffer.write('<img src=x>    ',n,'ascii');}
 await inspect(hostile);await passed();
 await page.locator('#private-reveal').focus();await page.keyboard.press('Enter');
 await page.locator('#private-values').waitFor({state:'visible'});
 assert.match(await page.locator('#private-value-rows').innerText(),/<img src=x>/);
 assert.ok((await page.locator('#private-panel').innerText()).includes('SYNTHETIC'));
 assert.equal(report.release_authorized,false);
 // Explicitly private DOM is excluded from the public output, no innerHTML.
 assert.equal(await page.locator('#private-value-rows img').count(),0);
 const beforeClose=(await page.evaluate(()=>window.privateMetrics)).terminated;
 await page.locator('#private-hide').click();assert.equal(await page.locator('#private-value-rows tr').count(),0);
 assert.equal(await page.locator('#private-export').isDisabled(),true);
 assert.equal((await page.evaluate(()=>window.privateMetrics)).terminated,beforeClose+1);checks.push('explicit-private-reveal-and-close-terminates-clears-input-and-values');
 const before=await page.evaluate(()=>window.privateMetrics.reads);
 await inspect([{name:'large.dcm',mimeType:'application/dicom',buffer:Buffer.alloc(8*1024*1024+1)}]);await blocked();
 assert.equal(await page.evaluate(()=>window.privateMetrics.reads),before);
 await inspect(Array.from({length:17},()=>fixtures[0]));await blocked();
 assert.equal(await page.evaluate(()=>window.privateMetrics.reads),before);
 await inspect(Array.from({length:3},()=>({name:'total.dcm',mimeType:'application/dicom',buffer:Buffer.alloc(6*1024*1024)})));await blocked();
 assert.equal(await page.evaluate(()=>window.privateMetrics.reads),before);checks.push('count-per-file-total-budgets-before-any-arrayBuffer');
 await inspect(fixtures);await passed();
 await inspect([{name:'bad.dcm',mimeType:'application/dicom',buffer:Buffer.from('PRIVATE-BAD-CANARY')}]);await blocked();
 assert.equal(await page.locator('#private-structures tr').count(),0);assert.equal(await page.locator('#private-export').isDisabled(),true);
 assert.ok(!(await page.locator('#private-panel').innerText()).includes('PRIVATE-BAD-CANARY'));
 await inspect([fixtures[0]]);await blocked(); // fixture 0 references fixture 1
 await inspect([fixtures[1],fixtures[1]]);await blocked();checks.push('malformed-unresolved-and-duplicate-refused-with-stale-result-cleared');
 await inspect(fixtures);await passed();await page.locator('#private-reveal').click();await page.locator('#private-values').waitFor({state:'visible'});
 await page.locator('#mode').selectOption('synthetic');await page.locator('#status[data-state="passed"]').waitFor();
 assert.equal(await page.locator('#private-value-rows tr').count(),0);assert.equal(await page.locator('#private-structures tr').count(),0);
 assert.equal(await page.locator('#private-export').isDisabled(),true);
 await page.locator('#mode').selectOption('private');assert.match(await page.locator('#private-status').innerText(),/选择文件/);
 checks.push('mode-switch-terminates-clears-separate-synthetic-and-private-states');
 // Same-task switch invalidates a pending original-value response.
 await inspect(fixtures);await passed();
 await page.evaluate(()=>{
   document.getElementById('private-reveal').click();
   const select=document.getElementById('private-object');select.value='1';select.dispatchEvent(new Event('change'));
 });
 await page.waitForTimeout(150);
 assert.equal(await page.locator('#private-value-rows tr').count(),0);
 assert.equal(await page.locator('#private-values').isVisible(),false);
 await page.locator('#private-reveal').click();await page.locator('#private-values').waitFor({state:'visible'});
 await page.locator('#private-hide').click();checks.push('pending-reveal-discarded-on-object-selection-change');
 // Pause the actual worker after construction, then cancel during file reading.
 // A real Worker is created/terminated; no completed message can repopulate DOM.
 await select(fixtures);
 await page.evaluate(()=>{
   const button=document.getElementById('private-check');button.click();document.getElementById('private-cancel').click();
 });
 await page.waitForFunction(()=>document.getElementById('private-status').textContent.includes('已取消'));
 assert.equal(await page.locator('#private-export').isDisabled(),true);
 assert.equal(await page.locator('#private-structures tr').count(),0);
 checks.push('cancel-during-async-read-stale-completion-discarded');
 // Actual wall deadline driven by browser clock, worker is terminated on timeout.
 await page.clock.install();await select(fixtures);
 await page.evaluate(()=>{document.getElementById('private-check').click();});
 await page.clock.fastForward(15001);
 await page.waitForFunction(()=>document.getElementById('private-status').textContent.includes('超时'));
 assert.equal(await page.locator('#private-export').isDisabled(),true);await page.clock.resume();checks.push('15-second-timeout-clears-and-terminates');
 await inspect(fixtures);await passed();await page.locator('#private-reveal').click();await page.locator('#private-values').waitFor({state:'visible'});
 await page.setViewportSize({width:390,height:844});
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.screenshot({path:path.join(root,'private-mobile.png'),fullPage:true});
 await page.locator('#private-hide').click();await page.setViewportSize({width:1280,height:900});
 await page.screenshot({path:path.join(root,'private-desktop.png'),fullPage:true});checks.push('390px-private-values-layout-no-page-overflow');
 const security=await page.evaluate(async()=>{
   const violations=[];document.addEventListener('securitypolicyviolation',e=>violations.push(e.effectiveDirective));
   const s=document.createElement('script');s.textContent='window.BAD_CANARY=true';document.body.append(s);
   try{await fetch('https://example.invalid/private-canary');}catch{}
   await new Promise(resolve=>setTimeout(resolve,100));
   return {ran:window.BAD_CANARY===true,violations,storage:window.privateMetrics.storage};
 });
 assert.equal(security.ran,false);assert.ok(security.violations.includes('connect-src'));assert.ok(security.violations.some(x=>x.startsWith('script-src')));
 assert.equal(security.storage,0);assert.equal(remote.length,0);assert.deepEqual(errors,[]);checks.push('actual-CSP-no-network-no-storage-writes');
 const workerSecurity=fs.readFileSync(path.join(repo,'web/private-worker.js'),'utf8');
 const ui=fs.readFileSync(path.join(repo,'web/private.js'),'utf8');
 for(const src of [workerSecurity,ui])assert.ok(!/\b(localStorage|indexedDB|sessionStorage|serviceWorker|fetch|XMLHttpRequest|sendBeacon)\b/.test(src));
 const result={schema:1,status:'passed',stage:'private-file-view',checks,browser:browser.version(),
   html_sha256:createHash('sha256').update(fs.readFileSync(path.join(root,'index.html'))).digest('hex'),
   resource_observation:{baseline_browser_rss_kib:baselineRss,loaded_browser_rss_kib:loadedRss,scope:'sum of descendant processes of isolated QA Node; one snapshot each; not peak or Worker-only heap'},
   private_input_budget:{objects:16,per_object:8388608,total:16777216,timeout_ms:15000},
   synthetic_only:true,actual_local_file_import_verified:true,release_authorized:false,
   limits:['headless Chromium only; not all assistive technologies','browser/OS memory erasure cannot be guaranteed','input remains original; no anonymized DICOM or pixel preview generated']};
 fs.writeFileSync(path.join(root,'private-acceptance.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
 await context.close();
} finally {await browser.close();}
