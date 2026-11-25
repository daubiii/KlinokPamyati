'use strict';
const fs = require('fs');
async function main() {
 const base='http://127.0.0.1:8799';
 const status=await (await fetch(base+'/status')).json();
 console.log(JSON.stringify(status));
 const tools=await (await fetch(base+'/rpc',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({method:'tools/list',params:{}})})).json();
 fs.writeFileSync('.sharrowkin/weapon-step1/bridge-tools.json', JSON.stringify(tools,null,2));
 console.log(JSON.stringify(tools));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
