'use strict';
const fs = require('fs');
async function main(){
 const base='http://127.0.0.1:8799';
 const status=await (await fetch(base+'/status')).json();
 const studio=status.studios && status.studios[0];
 if(!studio) throw Error('Studio не подключена');
 const name=process.argv[2];
 let args=process.argv[3] ? JSON.parse(fs.readFileSync(process.argv[3],'utf8')) : {};
 args.studio_id=studio.id;
 const out=await (await fetch(base+'/tool',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name,arguments:args})})).json();
 console.log(JSON.stringify(out,null,2));
 if(out.isError || out.error) process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exitCode=1;});
