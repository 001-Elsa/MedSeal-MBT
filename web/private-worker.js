// Fixed worker source bundled with the compiled MoonBit core. No network,
// persistence, filenames or original values cross the public message boundary.
let held = null;
function clear() { held = null; }
function blocked() { return {schema:1,status:'blocked',release_authorized:false,issue:{code:'MEDSEAL-E501'}}; }
self.onmessage = event => {
  const msg=event.data;
  try {
    if(msg.kind==='inspect') {
      clear();
      if(!Array.isArray(msg.buffers)||!msg.buffers.length||msg.buffers.length>16) throw Error();
      let total=0;
      for(const b of msg.buffers) {
        if(!(b instanceof ArrayBuffer)||!b.byteLength||b.byteLength>8*1024*1024) throw Error();
        total+=b.byteLength;if(total>16*1024*1024)throw Error();
      }
      held=msg.buffers.map(buffer=>new Uint8Array(buffer));
      const result=JSON.parse(inspect_private(held));
      if(result.status!=='passed')clear();
      self.postMessage({kind:'public',result});
    } else if(msg.kind==='reveal' && held && Number.isInteger(msg.index)) {
      self.postMessage({kind:'private',result:JSON.parse(reveal_private(held,msg.index))});
    } else { clear();self.postMessage({kind:'public',result:blocked()}); }
  } catch { clear();self.postMessage({kind:'public',result:blocked()}); }
};
