// Separate private-file state. Patient bytes are never passed to analyze(),
// the synthetic conversion engine, public exporter or the DOM.
let privateWorker=null, privateGeneration=0, privateTimer=null, privateReport=null, privateRequest=0;
const PRIVATE_LIMITS={objects:16,objectBytes:8*1024*1024,totalBytes:16*1024*1024};
const pstatus=text=>{$('private-status').textContent=text;};
function clearPrivateValues() {
  privateRequest++;
  $('private-value-rows').replaceChildren();$('private-values').hidden=true;
  $('private-reveal').disabled=true;
}
function terminatePrivate() {
  if(privateWorker)privateWorker.terminate();privateWorker=null;
  clearTimeout(privateTimer);privateTimer=null;
}
function resetPrivate(text='已清除本次检查；没有文件保存在页面中。') {
  privateGeneration++;terminatePrivate();privateReport=null;
  $('private-files').value='';$('private-structures').replaceChildren();
  $('private-object').replaceChildren();clearPrivateValues();
  $('private-export').disabled=true;$('private-cancel').disabled=true;
  $('private-check').disabled=false;pstatus(text);
}
function selectionAllowed(files) {
  if(!files.length||files.length>PRIVATE_LIMITS.objects)return false;
  let total=0;
  for(const file of files) {
    if(!Number.isSafeInteger(file.size)||file.size<=0||file.size>PRIVATE_LIMITS.objectBytes)return false;
    total+=file.size;if(total>PRIVATE_LIMITS.totalBytes)return false;
  }
  return true;
}
function renderPrivatePublic(result) {
  privateReport=null;$('private-export').disabled=true;
  $('private-structures').replaceChildren();$('private-object').replaceChildren();clearPrivateValues();
  if(result.status!=='passed') {
    pstatus(`检查已阻断 · ${result.issue?.code??'MEDSEAL-E501'}；没有部分成功结果。`);
    terminatePrivate();$('private-cancel').disabled=true;return;
  }
  // Construct the public export ourselves from the fixed core summary. Never
  // serialize the entire message, File metadata or private-view results.
  privateReport={schema:1,scope:'read-only-current-collection',status:'validated',
    objects:result.report.objects,references:result.report.references,
    release_authorized:false};
  pstatus(`只读检查通过：${privateReport.objects} 个对象，${privateReport.references} 个集合内引用。未转换、未脱敏、未授权交付。`);
  result.structures.forEach((structure,index)=>{
    const option=document.createElement('option');option.value=String(index);option.textContent=`对象 ${index+1}`;$('private-object').append(option);
    for(const item of structure.rows) {
      const row=document.createElement('tr');cell(row,`对象 ${index+1}`);cell(row,item.path);cell(row,item.vr);$('private-structures').append(row);
    }
  });
  $('private-export').disabled=false;$('private-reveal').disabled=false;
}
async function inspectSelection() {
  const files=Array.from($('private-files').files??[]);
  resetPrivate('正在检查文件数量与大小…');
  // File.size is checked before any arrayBuffer() call, including repeated runs.
  if(!selectionAllowed(files)) {
    pstatus('文件未读取：需要 1–16 个非空普通文件，每个至多 8 MiB，合计至多 16 MiB。');return;
  }
  const generation=privateGeneration;
  $('private-check').disabled=true;$('private-cancel').disabled=false;
  pstatus(`正在本机只读检查 ${files.length} 个对象…可随时取消。`);
  const workerURL=URL.createObjectURL(new Blob([PRIVATE_WORKER_SOURCE],{type:'text/javascript'}));
  try { privateWorker=new Worker(workerURL); }
  catch { resetPrivate('无法创建隔离检查任务；请使用支持 Worker 的本机浏览器。');return; }
  finally { URL.revokeObjectURL(workerURL); }
  privateWorker.onmessage=event=>{
    if(generation!==privateGeneration)return;
    const msg=event.data;
    if(msg.kind==='private' && msg.request!==privateRequest)return;
    clearTimeout(privateTimer);privateTimer=null;$('private-check').disabled=false;
    if(msg.kind==='public')renderPrivatePublic(msg.result);
    else if(msg.kind==='private') {
      $('private-reveal').disabled=false;
      $('private-value-rows').replaceChildren();
      if(msg.result.status!=='private-view') {resetPrivate('私有视图检查失败，已清除输入和旧结果。');return;}
      for(const item of msg.result.rows) {const row=document.createElement('tr');cell(row,item.path);cell(row,item.vr);cell(row,item.value);$('private-value-rows').append(row);}
      $('private-values').hidden=false;
      $('private-values-note').textContent=msg.result.truncated?'私有文本显示已截断（最多 128 项、每项 160 字符）。':'仅显示所选对象的私有文本；没有像素预览或私有导出。';
    }
  };
  privateWorker.onerror=event=>{event.preventDefault();if(generation===privateGeneration)resetPrivate('检查任务异常；已清除输入和旧结果。');};
  privateTimer=setTimeout(()=>{if(generation===privateGeneration)resetPrivate('检查超时（15 秒）；任务已终止，输入和旧结果已清除。');},15000);
  try {
    const buffers=[];
    for(const file of files) {
      const buffer=await file.arrayBuffer();
      if(generation!==privateGeneration)return;
      if(buffer.byteLength!==file.size)throw Error();
      buffers.push(buffer);
    }
    if(generation===privateGeneration)privateWorker.postMessage({kind:'inspect',buffers},buffers);
  } catch {if(generation===privateGeneration)resetPrivate('读取失败；已清除输入和旧结果。');}
}
$('private-check').addEventListener('click',inspectSelection);
$('private-files').addEventListener('change',()=>{
  // Clear old worker/results without dropping the newly selected FileList.
  privateGeneration++;terminatePrivate();privateReport=null;clearPrivateValues();
  $('private-export').disabled=true;$('private-structures').replaceChildren();$('private-object').replaceChildren();
  $('private-check').disabled=false;$('private-cancel').disabled=true;
  pstatus('文件已选择；开始检查前会先核对预算。文件名不写入结果。');
});
$('private-cancel').addEventListener('click',()=>resetPrivate('已取消；隔离任务终止，输入和结果已清除。'));
$('private-clear').addEventListener('click',()=>resetPrivate());
$('private-hide').addEventListener('click',()=>resetPrivate());
$('private-object').addEventListener('change',()=>{
  privateRequest++;clearTimeout(privateTimer);privateTimer=null;
  $('private-reveal').disabled=!privateReport;
  $('private-value-rows').replaceChildren();$('private-values').hidden=true;
});
$('private-reveal').addEventListener('click',()=>{
  if(!privateWorker||!privateReport)return;
  $('private-reveal').disabled=true;
  $('private-value-rows').replaceChildren();$('private-values').hidden=true;
  // Separate explicit action; original text never enters privateReport.
  privateWorker.postMessage({kind:'reveal',request:++privateRequest,index:Number($('private-object').value)});
  privateTimer=setTimeout(()=>resetPrivate('私有视图超时，输入和结果已清除。'),15000);
});
$('private-export').addEventListener('click',()=>{
  if(!privateReport)return;
  const url=URL.createObjectURL(new Blob([JSON.stringify(privateReport,null,2)],{type:'application/json'}));
  const link=document.createElement('a');link.href=url;link.download='medseal-readonly-public.json';link.click();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
});
$('mode').addEventListener('change',()=>{
  resetPrivate('选择文件后开始本机只读检查。');
  // Synthetic and private modes share no previous result, seed or policy state.
  lastResult=null;previous=null;$('export').disabled=true;
  $('structure-rows').replaceChildren();$('decision-rows').replaceChildren();$('comparison-rows').replaceChildren();
  $('comparison').hidden=true;$('changes').textContent=$('issue').textContent=$('truncated').textContent='';
  $('objects').textContent=$('references').textContent=$('decisions').textContent='—';
  const isPrivate=$('mode').value==='private';
  $('synthetic-layout').hidden=isPrivate;$('private-panel').hidden=!isPrivate;
  if(!isPrivate){preset();run();}
});
window.addEventListener('pagehide',()=>resetPrivate());
