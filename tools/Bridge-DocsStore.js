// Bridge-Delivery-ID: TB-20261102T061136Z-1D382738
// Bridge-Base-Commit: e59f1c54454a5e3294bb83c83337f31866387aa3
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {validate,hash,plan}=require('./Bridge-DocsCore.js');
const names=new Set(['ESTADO-ATUAL.md','DECISOES.md','TESTES.md']);
const digest=b=>crypto.createHash('sha256').update(b).digest('hex');
const decode=b=>new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(b);
function idCheck(id){if(typeof id!=='string'||!/^TB-\d{8}T\d{6}Z-[0-9A-F]{8}$/.test(id))throw Error('ID');}
function rootCheck(root){root=path.resolve(root);if(!fs.lstatSync(root).isDirectory()||fs.lstatSync(root).isSymbolicLink())throw Error('ROOT_LINK_OR_TYPE');return root;}
function within(root,parts,create=false){let p=rootCheck(root);for(const part of parts){if(!/^[A-Za-z0-9_.-]+$/.test(part)||['.','..'].includes(part))throw Error('PATH');p=path.join(p,part);if(!fs.existsSync(p)&&create)fs.mkdirSync(p);const s=fs.lstatSync(p);if(s.isSymbolicLink()||!s.isDirectory())throw Error('DIRECTORY_LINK_OR_TYPE');}return p;}
function regular(p){const s=fs.lstatSync(p);if(s.isSymbolicLink()||!s.isFile())throw Error('FILE_LINK_OR_TYPE');return p;}
function read(p,max=4194304){regular(p);if(fs.statSync(p).size>max)throw Error('FILE_SIZE');return fs.readFileSync(p);}
function createFile(p,bytes){const fd=fs.openSync(p,'wx');try{fs.writeFileSync(fd,bytes);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}}
function atomic(p,bytes){if(fs.existsSync(p))regular(p);const tmp=p+'.tmp-'+crypto.randomUUID();createFile(tmp,bytes);fs.renameSync(tmp,p);}
function json(p){return JSON.parse(decode(read(p)));}
function encode(value){return Buffer.from(JSON.stringify(value,null,2)+'\n','utf8');}
function layout(root,id){idCheck(id);const cache=within(root,['.git','bridge-docs'],true);const transactions=within(root,['.git','bridge-docs','transactions'],true);return {cache,tx:path.join(transactions,id),journal:path.join(transactions,id,'journal.json')};}
function doc(root,name){if(!names.has(name))throw Error('DESTINATION');return regular(path.join(rootCheck(root),name));}
function sourceCheck(s,id){if(!s||Object.keys(s).sort().join(',')!=='ledger_commit,record_blob,record_path'||!/^[a-f0-9]{40}$/.test(s.ledger_commit)||!/^[a-f0-9]{40}$/.test(s.record_blob)||s.record_path!=='documentacao/'+id+'.json')throw Error('SOURCE');}
function receiptPath(root,id){return path.join(within(root,['RASTREABILIDADE','documentacao'],true),id+'.json');}
function publishReceipt(root,j){
 const p=receiptPath(root,j.delivery_id),bytes=encode(j.public_receipt);
 if(fs.existsSync(p)){if(!read(p).equals(bytes))throw Error('RECEIPT_CONFLICT');return;}
 createFile(p,bytes);
}
function validateJournal(j,id){
 if(j.delivery_id!==id||!['PREPARED','APPLIED'].includes(j.state)||!Array.isArray(j.files)||!j.files.length||j.files.length>3||!j.receipt||!j.public_receipt)throw Error('JOURNAL');
 const seen=new Set();sourceCheck(j.source,id);
 for(const f of j.files){if(!names.has(f.path)||seen.has(f.path)||!/^[a-f0-9]{64}$/.test(f.before)||!/^[a-f0-9]{64}$/.test(f.after))throw Error('JOURNAL_FILE');seen.add(f.path);}
}
function apply(root,r,files,{source,failAfter=0,beforeWrite=null}={}){
 validate(r);sourceCheck(source,r.delivery_id);root=rootCheck(root);
 const loc=layout(root,r.delivery_id),docs={};for(const u of r.updates)docs[u.path]=decode(read(doc(root,u.path)));
 let previous=null;
 if(fs.existsSync(loc.tx)){within(root,['.git','bridge-docs','transactions',r.delivery_id]);if(!fs.existsSync(loc.journal))return {state:'RECOVERY_REQUIRED',reason:'JOURNAL_MISSING',writes:0};previous=json(loc.journal);validateJournal(previous,r.delivery_id);if(previous.source.record_blob!==source.record_blob)throw Error('SOURCE_ID_REUSED');if(previous.state!=='APPLIED')return {state:'RECOVERY_REQUIRED',writes:0};}
 const p=plan(docs,r,files,previous?previous.receipt:null);
 if(previous){if(p.state==='ALREADY_PRESENT'){publishReceipt(root,previous);return {state:'ALREADY_PRESENT',writes:0};}return {state:'RECOVERY_REQUIRED',reason:p.reason,writes:0};}
 if(p.state==='ALREADY_PRESENT')return {state:'RECOVERY_REQUIRED',reason:'BLOCK_PRESENT_WITHOUT_JOURNAL',writes:0};
 if(p.state!=='READY')return {state:p.state,reason:p.reason,writes:0};
 const publicPath=receiptPath(root,r.delivery_id);if(fs.existsSync(publicPath))throw Error('RECEIPT_WITHOUT_JOURNAL');
 fs.mkdirSync(loc.tx);
 for(const w of p.writes){const original=read(doc(root,w.path));if(digest(original)!==w.expectedRawSha256)throw Error('RACE_BEFORE_BACKUP');createFile(path.join(loc.tx,w.path+'.before'),original);createFile(path.join(loc.tx,w.path+'.after'),Buffer.from(w.content,'utf8'));}
 const publicReceipt={schema_version:'bridge-docs-receipt-v1',delivery_id:r.delivery_id,state:'INCORPORADA_LOCALMENTE',source,base_commit:r.base_commit,record_hash:p.recordHash,files:p.writes.map(w=>({path:w.path,before_sha256_raw:w.expectedRawSha256,after_sha256_raw:digest(Buffer.from(w.content)),after_sha256_normalized_utf8_lf:hash(w.content)})),meaning:'Evidencia de incorporacao documental local; nao declara commit final, publicacao, reload, teste ou aprovacao de gameplay.'};
 const j={delivery_id:r.delivery_id,state:'PREPARED',source,receipt:p.receipt,files:p.writes.map(w=>({path:w.path,before:w.expectedRawSha256,after:digest(Buffer.from(w.content))})),public_receipt:publicReceipt};
 createFile(loc.journal,encode(j));let count=0;
 for(const w of p.writes){if(beforeWrite)beforeWrite(w,count);const target=doc(root,w.path);if(digest(read(target))!==w.expectedRawSha256)throw Error('RACE_BEFORE_REPLACE');atomic(target,Buffer.from(w.content));if(digest(read(target))!==j.files.find(f=>f.path===w.path).after)throw Error('POST_HASH');count++;if(count===failAfter)throw Error('SIMULATED_INTERRUPTION');}
 j.state='APPLIED';atomic(loc.journal,encode(j));publishReceipt(root,j);return {state:'APPLIED',writes:count};
}
function recover(root,id,{complete=false}={}){
 root=rootCheck(root);idCheck(id);const loc=layout(root,id);within(root,['.git','bridge-docs','transactions',id]);const j=json(loc.journal);validateJournal(j,id);
 const report=j.files.map(f=>{const current=digest(read(doc(root,f.path)));const before=read(path.join(loc.tx,f.path+'.before')),after=read(path.join(loc.tx,f.path+'.after'));if(digest(before)!==f.before||digest(after)!==f.after)throw Error('BACKUP_OR_PROPOSAL_CHANGED');return {path:f.path,state:current===f.after?'APPLIED':current===f.before?'ORIGINAL':'CONFLICT',observed:current};});
 if(!complete)return {state:'RECOVERY_REPORT',files:report};
 if(report.some(x=>x.state==='CONFLICT'))throw Error('RECOVERY_CONFLICT');
 const pub=receiptPath(root,id);if(fs.existsSync(pub)&&!read(pub).equals(encode(j.public_receipt)))throw Error('RECEIPT_CONFLICT');
 let count=0;for(const item of report){const p=doc(root,item.path);if(digest(read(p))!==item.observed)throw Error('RECOVERY_RACE');if(item.state==='ORIGINAL'){atomic(p,read(path.join(loc.tx,item.path+'.after')));if(digest(read(p))!==j.files.find(f=>f.path===item.path).after)throw Error('RECOVERY_POST_HASH');count++;}}
 j.state='APPLIED';atomic(loc.journal,encode(j));publishReceipt(root,j);return {state:'RECOVERED',writes:count};
}
module.exports={apply,recover,decode};