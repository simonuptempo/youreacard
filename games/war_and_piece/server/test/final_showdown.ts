import assert from 'node:assert/strict';
import {Game,buildDeck} from '../functions/war-and-piece/engine.ts';
for(let seed=1;seed<=200;seed++) {
 const g=Game.create(['You','Rascal'],seed);
 for(const p of g.s.players) p.stock=[];
 let owner=0;
 for(let r=2;r<=14;r++) {
  const group=buildDeck().filter(c=>c.rank===r);
  if(r===11){g.hand(0).push(...group.slice(0,2));g.hand(1).push(...group.slice(2));}
  else g.sets(owner++%2).push(group);
 }
 g.s.round=4;g.startWarRound();
 assert.equal(g.sets(0).length+g.sets(1).length,13);
 assert.equal(g.sets(g.s.winner).length,7);
 const lf:any=g.s.last_faceoff;
 const totals=[0,0];
 for(let i=0;i<lf.cards[0].length;i++) {
  for(const p of [0,1]) totals[p]+=lf.cards[p][i].rank;
  if((i+1)%5===0 && i+1<lf.cards[0].length) assert.equal(totals[0],totals[1]);
 }
 assert.equal(lf.cards[0].length%5,0);
 assert.ok(totals[lf.winner]>totals[1-lf.winner]);
 const view:any=g.view(1);
 assert.equal(view.last_faceoff.winner,1-lf.winner);
}
for (const lead of [[8,4],[4,8],[7,5]]) {
 const g=Game.create(['You','Rascal'],3);
 for(const p of g.s.players) p.stock=[];
 const all:any[]=[];
 for(let r=2;r<=14;r++) {
  const group=buildDeck().filter(c=>c.rank===r);
  if(r===11){g.hand(0).push(...group.slice(0,2));g.hand(1).push(...group.slice(2));}
  else all.push(group);
 }
 g.s.players[0].sets=all.slice(0,lead[0]); g.s.players[1].sets=all.slice(lead[0]);
 g.s.round=4; g.startWarRound();
 assert.equal(g.s.winner, lead[0]>lead[1]?0:1);
 assert.notEqual((g.s.last_faceoff as any)?.reason, 'final_showdown');
 assert.equal(g.sets(0).length+g.sets(1).length,12);
}
console.log('SERVER FINAL SHOWDOWN OK: 200 seeds, seat rotation, no showdown unless 6-6');
