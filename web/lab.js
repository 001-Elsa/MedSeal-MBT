const $ = (id) => document.getElementById(id);
const notes = {
  linked: "两份 SC 合成影像，其中一份引用另一份。整组转换后重新核对引用。",
  unresolved: "只保留引用方，故意缺少目标。封闭集合应当拒绝处理。",
  duplicate: "同一 SOP 身份重复出现。应拒绝，而不是默默覆盖对象。",
  malformed: "截断第二份文件。整组应失败，不能显示部分成功。",
};
const actionText = {keep:"保留",empty:"清空",remove:"移除",replace:"替换",remap:"身份映射",shift:"日期平移",recurse:"递归处理"};
let lastResult = null;
let previous = null;
function cell(row, text) { const td=document.createElement("td"); td.textContent=text; row.append(td); return td; }
function preset() {
  const choice=$('preset').value;
  const policy={version:2,mode:"strict",namespace:"offline-synthetic-lab",date_shift_days:30};
  if(choice!=="empty") policy.path_rules=[{id:"lab-study-description",path:"dataset/00081030",action:choice==="remove"?"remove":"keep",priority:10}];
  $('policy').value=JSON.stringify(policy,null,2);
}
function renderDecisions() {
  const rows=$('decision-rows'); rows.replaceChildren();
  const decisions=lastResult?.report?.decisions?.[0]??[];
  const query=$('filter').value.toLowerCase();
  for(const d of decisions) {
    if(![d.path,d.action,d.rule_id,d.source].join(' ').toLowerCase().includes(query)) continue;
    const row=document.createElement('tr'); cell(row,d.path);
    const td=cell(row,''); const pill=document.createElement('span'); pill.className='pill';pill.textContent=actionText[d.action]??d.action;td.append(pill);
    cell(row,`${d.rule_id}\n${d.source}`);rows.append(row);
  }
  if(!rows.children.length) { const row=document.createElement('tr');const td=cell(row,decisions.length?'没有匹配的字段':'当前未生成转换决定');td.colSpan=3;rows.append(row); }
}
function run() {
  $('run').disabled=true;
  try {
    const scenario=$('scenario').value;
    const base=SAMPLES;
    const inputs=scenario==='linked'?base:scenario==='unresolved'?[base[0]]:scenario==='duplicate'?[base[1],base[1]]:[base[0],base[1].slice(0,100)];
    const result=JSON.parse(analyze(JSON.stringify(inputs),$('policy').value));
    lastResult=result;
    const passed=result.status==='passed';
    $('status').dataset.state=result.status;
    $('status').textContent=passed?'整组转换与关联核验通过 · 交付未授权':`已阻断处理 · ${result.issue?.code??'未知错误'}`;
    $('objects').textContent=passed?String(result.report.objects):'—';
    $('references').textContent=passed?String(result.report.references):'—';
    $('decisions').textContent=passed?String(result.report.decisions.reduce((n,a)=>n+a.length,0)):'—';
    const tree=$('structure-rows');tree.replaceChildren();
    for(const item of result.structures?.[0]?.rows??[]) { const row=document.createElement('tr');cell(row,item.path);cell(row,item.vr);tree.append(row); }
    $('truncated').textContent=result.structures?.[0]?.truncated?'结构展示已达到 512 节点上限。':'';
    $('issue').textContent=passed?'当前批次内对象与引用已重新校验。\n公开报告：release_authorized = false\n未执行：像素 OCR、人工复核或交付。':JSON.stringify(result.issue,null,2);
    $('changes').textContent='';
    if(passed) {
      const current=new Map(result.report.decisions[0].map(d=>[d.path,d.action]));
      if(previous?.scenario===scenario) {
        const changed=[...current].filter(([path,action])=>previous.map.get(path)!==action);
        $('changes').textContent=changed.length?changed.map(([path,action])=>`${path}：${actionText[previous.map.get(path)]??previous.map.get(path)??'新增'} → ${actionText[action]??action}`).join('；'):'与上次成功运行相比，动作未变化。';
      }
      previous={scenario,map:current};
    }
    $('export').disabled=false;renderDecisions();
  } catch {
    lastResult=null;$('export').disabled=true;$('status').dataset.state='error';
    $('status').textContent='实验室运行异常，请重新生成页面或查看核心构建检查。';
    $('objects').textContent=$('references').textContent=$('decisions').textContent='—';
    $('structure-rows').replaceChildren();$('changes').textContent='';$('truncated').textContent='';
    $('issue').textContent='界面未产生可用结果。';renderDecisions();
  } finally { $('run').disabled=false; }
}
$('preset').addEventListener('change',preset);
$('scenario').addEventListener('change',()=>{$('scenario-note').textContent=notes[$('scenario').value];});
$('filter').addEventListener('input',renderDecisions);
$('run').addEventListener('click',run);
$('export').addEventListener('click',()=>{
  if(!lastResult)return;
  const report=lastResult.report??{schema:1,status:'blocked',release_authorized:false,issue:lastResult.issue};
  const url=URL.createObjectURL(new Blob([JSON.stringify(report,null,2)],{type:'application/json'}));
  const link=document.createElement('a');link.href=url;link.download='medseal-public-explanation.json';link.click();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
});
$('build').textContent=`核心 SHA-256 ${BUILD.engine_sha256.slice(0,16)}…\n源码基线 ${BUILD.source_base_commit.slice(0,7)}`;
$('scenario-note').textContent=notes.linked;preset();run();
