import assert from 'node:assert/strict';
import {Game,buildDeck} from '../functions/war-and-piece/engine.ts';
for(const winner of [0,1]){
 const g=Game.create(['You','Rascal'],9);
 for(const p of g.s.players)p.stock=[];
 let owner=0;
 for(let rank=2;rank<=14;rank++){
  const cards=buildDeck().filter(c=>c.rank===rank);
  if(rank===11)g.hand(winner).push(...cards);else g.sets(owner++%2).push(cards);
 }
 g.s.round=4;g.autoBank(winner);
 assert.equal(g.s.winner,winner);
 assert.equal(g.pieceActor(),-1);
}
console.log('SERVER INSTANT END OK');
