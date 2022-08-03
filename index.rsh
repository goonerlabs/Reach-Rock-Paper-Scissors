'reach 0.1';

const [isHand, ROCK, PAPER, SCISSORS] = makeEnum(3);
const [isOutcome, B_WINS, DRAW, A_WINS] = makeEnum(3);

const winner = (handAlice, handBob) => ((handAlice + (4 - handBob)) % 3);

assert(winner(ROCK, PAPER) == B_WINS);
assert(winner(PAPER, ROCK) == A_WINS);
assert(winner(ROCK, ROCK) == DRAW);

forall(UInt, handAlice => 
 forall(UInt, handBob => 
  assert(isOutcome(winner(handAlice, handBob)))));

forall(UInt, hand => 
 assert(winner(hand, hand) == DRAW));

const player = {
 ...hasRandom,
 getHand: Fun([], UInt),
 seeOutcome: Fun([UInt], Null),
 informTimeout: Fun([], Null),
};

// participant interact interface
export const main = Reach.App(() => {
 const Alice = Participant('Alice', {
  // interact interface
  ...player,
  wager: UInt,
  deadline: UInt,
 });
 const Bob = Participant('Bob', {
  // interact interface
  ...player,
  acceptWager: Fun([UInt], Null)
 });
 init();

 const informTimeout = () => {
  each([Alice, Bob], () => {
   interact.informTimeout();
  });
 }

 Alice.only(() => {
  const wager = declassify(interact.wager);
  const deadline = declassify(interact.deadline);
 });
 Alice.publish(wager, deadline).pay(wager);
 commit();

 Bob.only(() => {
  interact.acceptWager(wager);
 });
 Bob.pay(wager).timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));
 
 var outcome = DRAW;
 invariant(balance() == 2 * wager && isOutcome(outcome));
 while(outcome == DRAW) {
  commit();

  Alice.only(() => {
    const _handAlice = interact.getHand();
    const [_commitAlice, _saltAlice] = makeCommitment(interact, _handAlice);
    const commitAlice = declassify(_commitAlice);
  });
  Alice.publish(commitAlice).timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
  commit();

  unknowable(Bob, Alice(_handAlice, _saltAlice));

  Bob.only(() => {
    const handBob = declassify(interact.getHand());
  });

  Bob.publish(handBob).timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));
  commit();

  Alice.only(() => {
  const saltAlice = declassify(_saltAlice);
  const handAlice = declassify(_handAlice);
 });

 Alice.publish(saltAlice, handAlice).timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
 checkCommitment(commitAlice, saltAlice, handAlice);

 outcome = (handAlice + (4 - handBob)) % 3;
 continue;
 }
 const [forAlice, forBob] = outcome == 2 ? [2, 0] : [0, 2];
 transfer(forAlice * wager).to(Alice);
 transfer(forBob * wager).to(Bob);
 commit()

 each([Alice, Bob], () => {
  interact.seeOutcome(outcome)
 })
 exit();

});