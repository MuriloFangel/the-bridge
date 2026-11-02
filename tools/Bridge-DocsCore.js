// Bridge-Delivery-ID: TB-20261102T061136Z-1D382738
// Bridge-Base-Commit: e59f1c54454a5e3294bb83c83337f31866387aa3
'use strict';
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const allowed=new Set(['ESTADO-ATUAL.md','DECISOES.md','TESTES.md']);
const norm=s=>s.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n');
const hash=s=>crypto.createHash('sha256').update(norm(s),'utf8').digest('hex');
const rawHash=s=>crypto.createHash('sha256').update(s,'utf8').digest('hex');
const hex=s=>typeof s==='string'&&/^[a-f0-9]{64}$/.test(s);
function exact(o,keys){if(!o||typeof o!=='object'||Array.isArray(o)||Object.keys(o).some(k=>!keys.includes(k))||keys.some(k=>!Object.hasOwn(o,k)))throw Error('STRUCTURE');}
function validPath(p){return typeof p==='string'&&p.length>0&&p.length<512&&!p.includes('\\')&&!p.includes(':')&&!p.startsWith('/')&&!p.includes('\0')&&p.split('/').every(s=>s&&!['.','..','.git'].includes(s))&&!/^[a-z]:/i.test(p);}
function validate(r){
 exact(r,['schema_version','delivery_id','created_at','base_commit','requires','updates']);
 if(r.schema_version!=='bridge-docs-v1'||!/^TB-\d{8}T\d{6}Z-[0-9A-F]{8}$/.test(r.delivery_id)||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(r.created_at)||!Number.isFinite(Date.parse(r.created_at))||!/^[a-f0-9]{40}$/.test(r.base_commit))throw Error('IDENTITY');
 const idDate=r.delivery_id.slice(3,18);
 if(new Date(r.created_at).toISOString().replace(/[-:]/g,'').slice(0,15)!==idDate)throw Error('ID_DATE');
 if(!Array.isArray(r.requires)||r.requires.length>128||!Array.isArray(r.updates)||!r.updates.length||r.updates.length>3)throw Error('COUNT');
 let seen=new Set();
 for(const f of r.requires){exact(f,['path','sha256_normalized_utf8_lf']);if(!validPath(f.path)||!hex(f.sha256_normalized_utf8_lf)||seen.has(f.path.toLowerCase()))throw Error('DEPENDENCY');seen.add(f.path.toLowerCase());}
 seen=new Set();
 for(const u of r.updates){
 exact(u,['path','base_sha256_normalized_utf8_lf','content','content_sha256_normalized_utf8_lf']);
 if(!allowed.has(u.path)||seen.has(u.path)||!hex(u.base_sha256_normalized_utf8_lf)||!hex(u.content_sha256_normalized_utf8_lf)||typeof u.content!=='string'||!u.content.trim()||Buffer.byteLength(u.content,'utf8')>65536||u.content.includes('BRIDGE DOC'))throw Error('UPDATE');
 if(hash(u.content)!==u.content_sha256_normalized_utf8_lf)throw Error('CONTENT_HASH');seen.add(u.path);
 }
 if(Buffer.byteLength(JSON.stringify(r),'utf8')>262144)throw Error('SIZE');
}
function plan(documents,r,files,receipt=null){
 validate(r);const recordHash=rawHash(JSON.stringify(r));
 const pending=reason=>({state:'PENDING',reason,recordHash,writes:[]});
 if(receipt){
  exact(receipt,['recordHash','outputs']);
  if(receipt.recordHash!==recordHash)throw Error('ID_REUSED');
  if(!Array.isArray(receipt.outputs)||receipt.outputs.length!==r.updates.length)throw Error('RECEIPT');
  const seen=new Set();
  for(const out of receipt.outputs){exact(out,['path','block']);if(!r.updates.some(u=>u.path===out.path)||seen.has(out.path)||typeof out.block!=='string')throw Error('RECEIPT');seen.add(out.path);}
 }
 const outputs=r.updates.map(u=>({path:u.path,block:'<!-- BEGIN BRIDGE DOC '+r.delivery_id+' -->\n'+norm(u.content)+(norm(u.content).endsWith('\n')?'':'\n')+'<!-- END BRIDGE DOC '+r.delivery_id+' -->'}));
 if(receipt&&outputs.some((o,i)=>!receipt.outputs.some(x=>x.path===o.path&&x.block===o.block)))throw Error('RECEIPT');
 for(const o of outputs){if(!Object.hasOwn(documents,o.path)||typeof documents[o.path]!=='string')return pending('DOCUMENT_MISSING');}
 const marker='<!-- BEGIN BRIDGE DOC '+r.delivery_id+' -->';
 const markerCounts=outputs.map(o=>norm(documents[o.path]).split(marker).length-1);
 const has=outputs.map((o,i)=>markerCounts[i]===1&&norm(documents[o.path]).includes(o.block));
 if(has.every(Boolean))return {state:'ALREADY_PRESENT',recordHash,writes:[],receipt:{recordHash,outputs}};
 if(receipt||markerCounts.some(n=>n>0))return pending('PARTIAL_OR_EDITED_BLOCK');
 for(const f of r.requires){if(!Object.hasOwn(files,f.path)||typeof files[f.path]!=='string'||hash(files[f.path])!==f.sha256_normalized_utf8_lf)return pending('DEPENDENCY_MISMATCH');}
 for(const u of r.updates){if(hash(documents[u.path])!==u.base_sha256_normalized_utf8_lf)return pending('DOCUMENT_CONFLICT');}
 const writes=outputs.map(o=>({path:o.path,expectedRawSha256:rawHash(documents[o.path]),content:documents[o.path]+(documents[o.path].endsWith('\n')?'\n':'\n\n')+o.block+'\n'}));
 return {state:'READY',recordHash,writes,receipt:{recordHash,outputs}};
}
module.exports={norm,hash,validate,plan};
