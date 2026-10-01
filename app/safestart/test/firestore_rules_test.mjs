// Local emulator only. No live Firebase account, project writes, or npm packages.
import assert from 'node:assert/strict';
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const project = 'demo-safestart';
const root = `projects/${project}/databases/(default)/documents`;
const url = `http://${host}/v1/${root}`;
function token(uid) {
  const encode = v => Buffer.from(JSON.stringify(v)).toString('base64url');
  return `${encode({alg:'none',typ:'JWT'})}.${encode({sub:uid,user_id:uid,email:`${uid}@example.com`,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'password'}})}.`;
}
async function request(path, uid, body) {
  return fetch(`${url}${path}`, { method: body ? 'POST' : 'GET', headers: {'Content-Type':'application/json', ...(uid ? {Authorization:`Bearer ${token(uid)}`} : {})}, ...(body ? {body:JSON.stringify(body)} : {}) });
}
const stringValue = value => ({stringValue:value});
function profile(uid, extra = {}) {
  return {update:{name:`${root}/users/${uid}`,fields:{fullName:stringValue('Test User'),employeeId:stringValue('EMP1'),email:stringValue(`${uid}@example.com`),userType:stringValue('employee'),emergencyContact:{nullValue:null},...extra}},updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'},{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]};
}
async function status(response, expected, label) {
  const body = await response.text();
  assert.equal(response.status, expected, `${label}: ${body}`);
}
await status(await request(':commit','alice',{writes:[profile('alice')]}),200,'owner creates profile');
await status(await request('/users/alice','alice'),200,'owner reads profile');
await status(await request('/users/alice','bob'),403,'other user cannot read');
await status(await request('/users/alice',null),403,'anonymous cannot read');
await status(await request(':commit','bob',{writes:[profile('alice')]}),403,'other user cannot write');
await status(await request(':commit','bob',{writes:[profile('bob',{password:stringValue('forbidden')})]}),403,'credentials cannot be stored');
const editContact = {update:{name:`${root}/users/alice`,fields:{emergencyContact:{mapValue:{fields:{name:stringValue('Family'),phoneNumber:stringValue('+94771234567'),relationship:stringValue('family')}}}}},updateMask:{fieldPaths:['emergencyContact']},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]};
await status(await request(':commit','alice',{writes:[editContact]}),200,'owner updates contact while preserving createdAt');
const editEmail = {update:{name:`${root}/users/alice`,fields:{email:stringValue('other@example.com')}},updateMask:{fieldPaths:['email']},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]};
await status(await request(':commit','alice',{writes:[editEmail]}),403,'profile email must match Auth');
await status(await request(':commit',null,{writes:[profile('anonymous')]}),403,'anonymous cannot write');
const record = {update:{name:`${root}/users/alice/tests/one`,fields:{testType:stringValue('vehicle'),sensorReading:{doubleValue:0.5},status:stringValue('danger'),timestamp:{timestampValue:new Date().toISOString()},source:stringValue('simulation'),isPrototype:{booleanValue:true}}}};
await status(await request(':commit','alice',{writes:[record]}),200,'owner creates prototype result');
await status(await request('/users/alice/tests/one','alice'),200,'owner reads result');
await status(await request('/users/alice/tests/one','bob'),403,'other user cannot read results');
await status(await request(':commit','alice',{writes:[record]}),403,'saved results immutable');
const bad = structuredClone(record); bad.update.name = `${root}/users/alice/tests/bad`; bad.update.fields.status = stringValue('safe');
await status(await request(':commit','alice',{writes:[bad]}),403,'incorrect classification rejected');
const hardware = structuredClone(record); hardware.update.name = `${root}/users/alice/tests/hardware`; hardware.update.fields.source = stringValue('hardware');
await status(await request(':commit','alice',{writes:[hardware]}),403,'hardware claim rejected');
console.log('15 Firestore rule checks passed against the local emulator.');
