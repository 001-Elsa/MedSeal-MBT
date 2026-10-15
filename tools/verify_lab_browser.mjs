// Actual isolated Chromium rendering, CSP enforcement, keyboard and download.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(path.join(repo,'web/package.json'));
const {chromium}=require('playwright');
const root=path.resolve(process.argv[2]??path.join(repo,'tmp/community-lab'));
const executablePath=process.env.MEDSEAL_CHROME;
const browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
const checks=[];const errors=[];const remote=[];
try {
  const context=await browser.newContext({viewport:{width:1280,height:900},acceptDownloads:true});
  const page=await context.newPage();
  page.on('pageerror',error=>errors.push(error.message));
  page.on('request',request=>{if(/^https?:/.test(request.url()))remote.push(request.url());});
  await page.goto(pathToFileURL(path.join(root,'index.html')).href);
  await page.locator('#status[data-state="passed"]').waitFor();
  assert.equal(await page.locator('#objects').innerText(),'2');checks.push('actual-compiled-core-in-rendered-browser');
  // Browser-native select change, then real keyboard button activation; no DOM shim.
  await page.locator('#preset').selectOption('remove');
  await page.locator('#run').focus();await page.keyboard.press('Enter');
  assert.match(await page.locator('#changes').innerText(),/清空 → 移除/);
  assert.match(await page.locator('#comparison-rows').innerText(),/0008,1030/);checks.push('keyboard-and-field-action-comparison');
  await page.locator('#filter').fill('0008,1030');
  assert.equal(await page.locator('#decision-rows tr').count(),1);checks.push('field-filter');
  const downloadPromise=page.waitForEvent('download');await page.locator('#export').click();
  const download=await downloadPromise;await download.saveAs(path.join(root,'browser-public.json'));
  const exported=JSON.parse(fs.readFileSync(path.join(root,'browser-public.json'),'utf8'));
  assert.equal(exported.release_authorized,false);assert.equal(exported.objects,2);
  for(const canary of ['SYNTHETIC-ID','SYNTHETIC^SOURCE','987654321','20240229','1.2.3.30'])assert.ok(!JSON.stringify(exported).includes(canary));
  checks.push('real-download-and-public-canary');
  await page.locator('#scenario').selectOption('unresolved');await page.locator('#run').click();
  assert.equal(await page.locator('#status').getAttribute('data-state'),'blocked');
  assert.equal(await page.locator('#objects').innerText(),'—');
  assert.equal(await page.locator('#structure-rows tr').count(),0);
  assert.equal(await page.locator('#comparison-rows tr').count(),0);
  checks.push('blocked-clears-success-and-comparison');
  await page.locator('#scenario').selectOption('linked');await page.locator('#preset').selectOption('invalid');await page.locator('#run').click();
  assert.match(await page.locator('#issue').innerText(),/MEDSEAL-E510/);
  await page.locator('#preset').selectOption('empty');await page.locator('#run').click();
  assert.equal(await page.locator('#status').getAttribute('data-state'),'passed');checks.push('failure-recovery');
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));
  await page.screenshot({path:path.join(root,'browser-mobile.png'),fullPage:true});checks.push('390px-no-page-horizontal-overflow');
  await page.setViewportSize({width:1280,height:900});
  await page.evaluate(()=>window.scrollTo(0,0));
  await page.screenshot({path:path.join(root,'browser-desktop.png')});
  // Browser actually enforces the meta policy, not just string/hash comparison.
  const enforcement=await page.evaluate(async()=>{
    const violations=[];document.addEventListener('securitypolicyviolation',e=>violations.push(e.effectiveDirective));
    const script=document.createElement('script');script.textContent='window.__medseal_untrusted_script=true';document.body.append(script);
    let networkBlocked=false;try{await fetch('https://example.invalid/medseal-csp-probe');}catch{networkBlocked=true;}
    await new Promise(resolve=>setTimeout(resolve,100));
    return {scriptRan:window.__medseal_untrusted_script===true,networkBlocked,violations};
  });
  assert.equal(enforcement.scriptRan,false);assert.equal(enforcement.networkBlocked,true);
  assert.ok(enforcement.violations.some(x=>x.startsWith('script-src')));assert.ok(enforcement.violations.includes('connect-src'));
  assert.equal(remote.length,0);assert.deepEqual(errors,[]);checks.push('CSP-executes-blocks-script-and-network');
  const result={schema:1,status:'passed',stage:'V5',checks,browser:browser.version(),viewportWidths:[1280,390],
    html_sha256:createHash('sha256').update(fs.readFileSync(path.join(root,'index.html'))).digest('hex'),
    rendered_browser_verified:true,csp_enforcement_verified:true,keyboard_verified:true,release_authorized:false,
    limits:['isolated headless Chromium; not all browsers/assistive technologies','this test covers synthetic teaching mode; private-file mode is tested separately']};
  fs.writeFileSync(path.join(root,'browser-acceptance.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));await context.close();
}finally{await browser.close();}
