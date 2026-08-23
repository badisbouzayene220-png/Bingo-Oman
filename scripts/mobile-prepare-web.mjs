import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const out = path.join(root, 'www');
const skipDirs = new Set(['.git','.github','node_modules','www','android','ios','supabase','scripts']);
const skipExt = new Set(['.sql','.md','.txt','.zip','.odt','.doc','.docx','.pdf','.ppt','.pptx','.xls','.xlsx']);
const skipNames = new Set(['package.json','package-lock.json','capacitor.config.ts']);

fs.rmSync(out,{recursive:true,force:true});
fs.mkdirSync(out,{recursive:true});

function copyDir(src,dst,relative=''){
  for(const ent of fs.readdirSync(src,{withFileTypes:true})){
    if(relative==='' && skipDirs.has(ent.name)) continue;
    if(relative==='' && skipNames.has(ent.name)) continue;
    const from=path.join(src,ent.name), rel=path.join(relative,ent.name), to=path.join(dst,ent.name);
    if(ent.isDirectory()){
      if(skipDirs.has(ent.name)) continue;
      fs.mkdirSync(to,{recursive:true});
      copyDir(from,to,rel);
    }else{
      if(skipExt.has(path.extname(ent.name).toLowerCase())) continue;
      fs.copyFileSync(from,to);
    }
  }
}

copyDir(root,out);
if(!fs.existsSync(path.join(out,'index.html'))) throw new Error('index.html was not copied to www');
console.log('BINGO mobile web bundle prepared in www/');
