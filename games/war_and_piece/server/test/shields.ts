import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Game} from '../functions/war-and-piece/engine.ts';
const cases=JSON.parse(readFileSync('/tmp/wp_shield_cases.json','utf8'));
for(const c of cases){
 const g=new Game(c.legacy??c.before);
 if(c.move) assert.equal(g.apply(c.move),c.ok);
 assert.deepEqual(g.s,c.after);
 assert.equal(g.totalCards(),52); assert.equal(g.totalShields(),2);
 for(const seat of [0,1]){
  const v:any=g.view(seat);
  assert.deepEqual(v.shields,[g.s.shields![seat],-1]);
  for(const key of ['shield_pool','shields_spent','shield_draws']) assert(!(key in v));
  assert(v.players[1].hand.every((card:any)=>card.id===0));
  assert.deepEqual(v.heist_order,g.s.heist_order!.map(p=>p===seat?0:1));
  assert.deepEqual(v.heist_options,g.heistOptions(seat));
  // Changing the opponent's unused shields must not change this viewer's payload.
  const copy=new Game(structuredClone(g.s)); copy.s.shields![1-seat]=99;
  assert.deepEqual(copy.view(seat),g.view(seat));
 }
}
console.log(`SHIELD SERVER OK: ${cases.length} fixtures; shield ownership, draws, and hidden hand privacy verified`);
