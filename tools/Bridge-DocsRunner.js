// Bridge-Delivery-ID: TB-20261102T061136Z-1D382738
// Bridge-Base-Commit: e59f1c54454a5e3294bb83c83337f31866387aa3
'use strict';
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto');
const {validate,hash}=require('./Bridge-DocsCore.js');
const {apply,decode}=require('./Bridge-DocsStore.js');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function g(root,args,timeout=15000){return cp.execFileSync('git',['--no-optional-locks','-C',root,...args],{timeout,maxBuffer:2097152,windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,GIT_TERMINAL_PROMPT:'0',GCM_INTERACTIVE:'never'}});}
function gt(root,args){return decode(g(root,args)).replace(/[\r\n]+$/,'');}
function directory(root,parts,create=false){let p=path.resolve(root);if(fs.lstatSync(p).isSymbolicLink()||!fs.lstatSync(p).isDirectory())throw Error('ROOT');for(const part of parts){p=path.join(p,part);if(!fs.existsSync(p)&&create)fs.mkdirSync(p);const s=fs.lstatSync(p);if(s.isSymbolicLink()||!s.isDirectory())throw Error('DIRECTORY');}return p;}
function read(p){const s=fs.lstatSync(p);if(s.isSymbolicLink()||!s.isFile()||s.size>4194304)throw Error('FILE');return fs.readFileSync(p);}
function save(p,value){if(fs.existsSync(p))read(p);const tmp=p+'.tmp-'+crypto.randomUUID();fs.writeFileSync(tmp,JSON.stringify(value,null,2)+'\n',{flag:'wx'});fs.renameSync(tmp,p);}
function preflight(root){
 const tx=path.join(directory(root,['.git','bridge-docs'],true),'transactions');
 if(!fs.existsSync(tx))return;directory(root,['.git','bridge-docs','transactions']);
 for(const name of fs.readdirSync(tx)){if(!/^TB-\d{8}T\d{6}Z-[0-9A-F]{8}$/.test(name))throw Error('TRANSACTION_NAME');directory(root,['.git','bridge-docs','transactions',name]);const j=JSON.parse(decode(read(path.join(tx,name,'journal.json'))));if(j.delivery_id!==name||j.state!=='APPLIED')throw Error('RECOVERY_REQUIRED:'+name);
 const pub=path.join(directory(root,['RASTREABILIDADE','documentacao']),name+'.json');const expected=Buffer.from(JSON.stringify(j.public_receipt,null,2)+'\n');if(!read(pub).equals(expected))throw Error('RECEIPT_RECOVERY_REQUIRED:'+name);}
}
function dependency(root,p){
 if(!/^plugins\/Skript\/scripts\/[A-Za-z0-9_-][A-Za-z0-9_.-]*\.sk$/.test(p))throw Error('DEPENDENCY_SCOPE');
 directory(root,['plugins','Skript','scripts']);return decode(read(path.join(root,...p.split('/'))));
}
function cycle(root,{fetchRemote=true}={}){
 root=path.resolve(root);if(gt(root,['branch','--show-current'])!=='main')throw Error('BRANCH');
 const cache=directory(root,['.git','bridge-docs'],true),lock=path.join(cache,'lock');let fd;
 try{fd=fs.openSync(lock,'wx');}catch(e){if(e.code==='EEXIST')throw Error('LOCK_EXISTS_REQUIRES_REVIEW');throw e;}
 try{
 fs.writeFileSync(fd,JSON.stringify({pid:process.pid,created_at:new Date().toISOString()})+'\n');fs.fsyncSync(fd);preflight(root);
 const head=gt(root,['rev-parse','HEAD']),fetchPath=path.join(cache,'fetch.json');
 if(fetchRemote){let previous=null;if(fs.existsSync(fetchPath))previous=JSON.parse(decode(read(fetchPath)));
 if(!previous||Date.now()-previous.attempt_ms>=60000){let success=true;try{g(root,['fetch','--no-tags','origin','refs/heads/ai-deliveries:refs/remotes/origin/ai-deliveries'],120000);}catch{success=false;}previous={attempt_ms:Date.now(),success};save(fetchPath,previous);}
 if(!previous.success)return {state:'LEDGER_UNAVAILABLE',results:[],stopBeforeStage:false};}
 let ledger;try{ledger=gt(root,['rev-parse','--verify','refs/remotes/origin/ai-deliveries^{commit}']);}catch{return {state:'LEDGER_MISSING',results:[],stopBeforeStage:false};}
 if(!/^[a-f0-9]{40}$/.test(ledger))throw Error('LEDGER_SHA');
 const raw=decode(g(root,['ls-tree','-r','-z',ledger,'--','documentacao/']));
 const entries=raw.split('\0').filter(Boolean);if(entries.length>256)throw Error('RECORD_COUNT');
 const seenPath=path.join(cache,'seen.json'),seen=fs.existsSync(seenPath)?JSON.parse(decode(read(seenPath))):{};
 const loaded=[],results=[];let seenChanged=false;
 for(const entry of entries){
 const m=/^(\d{6}) blob ([a-f0-9]{40})\t(.+)$/.exec(entry);if(!m)throw Error('LEDGER_TREE');const [,mode,blob,name]=m;if(!name.endsWith('.json'))continue;
 try{
  const match=/^documentacao\/(TB-\d{8}T\d{6}Z-[0-9A-F]{8})\.json$/.exec(name);if(!match||mode!=='100644')throw Error('RECORD_PATH_OR_MODE');const id=match[1];
  if(Object.hasOwn(seen,id)&&seen[id]!==blob)throw Error('IMMUTABLE_ID_CHANGED');if(!Object.hasOwn(seen,id)){seen[id]=blob;seenChanged=true;}
  const bytes=g(root,['show',ledger+':'+name]);if(bytes.length>262144)throw Error('RECORD_SIZE');const r=JSON.parse(decode(bytes).replace(/^\uFEFF/,''));validate(r);if(r.delivery_id!==id)throw Error('FILENAME_ID');
  if(r.requires.some(f=>!/^plugins\/Skript\/scripts\/[A-Za-z0-9_-][A-Za-z0-9_.-]*\.sk$/.test(f.path)))throw Error('DEPENDENCY_SCOPE');
  loaded.push({name,blob,r});
 }catch(e){results.push({path:name,state:'INVALID',reason:e.message});}
 }
 if(seenChanged)save(seenPath,seen);
 loaded.sort((a,b)=>a.r.created_at.localeCompare(b.r.created_at)||a.r.delivery_id.localeCompare(b.r.delivery_id));
 for(const item of loaded){const {r,name,blob}=item;let reason=null;
 try{g(root,['merge-base','--is-ancestor',r.base_commit,head]);}catch{reason='BASE_NOT_ANCESTOR_OR_UNKNOWN';}
 if(!reason){for(const u of r.updates){try{if(hash(decode(g(root,['show',r.base_commit+':'+u.path])))!==u.base_sha256_normalized_utf8_lf)reason='DECLARED_DOCUMENT_BASE_MISMATCH';}catch{reason='DOCUMENT_BASE_MISSING';}if(reason)break;}}
 if(reason){results.push({delivery_id:r.delivery_id,state:'PENDING',reason});continue;}
 const files={};for(const f of r.requires){try{files[f.path]=dependency(root,f.path);}catch(e){if(e.code!=='ENOENT')throw e;}}
 const outcome=apply(root,r,files,{source:{ledger_commit:ledger,record_blob:blob,record_path:name}});
 results.push({delivery_id:r.delivery_id,...outcome});if(outcome.state==='RECOVERY_REQUIRED')throw Error('RECOVERY_REQUIRED:'+r.delivery_id);
 }
 return {state:'OK',head,ledger,results,stopBeforeStage:false};
 }finally{try{if(fd!==undefined)fs.closeSync(fd);}finally{if(fd!==undefined)fs.unlinkSync(lock);}}
}
function main(){
 if(process.argv.length!==4||process.argv[2]!=='--project')throw Error('Use --project CAMINHO');
 const root=path.resolve(process.argv[3]),result=cycle(root),cache=directory(root,['.git','bridge-docs']),p=path.join(cache,'last-status.json');
 const summary=JSON.stringify({state:result.state,results:result.results});const previous=fs.existsSync(p)?JSON.parse(decode(read(p))):null;
 if(!previous||previous.summary!==summary){save(p,{summary});console.log('Documentacao: '+summary);}
}
module.exports={cycle,preflight};
if(require.main===module){try{main();}catch(e){console.error('STOP: Importador documental: '+e.message);process.exitCode=1;}}