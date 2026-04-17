---
name: plan-debate
kind: program
services: [linus, prime, theo]
---

requires:
- topic: what is being debated — a bug with its diagnosis, a feature request, or any technical decision
- context: any additional material (diagnosis for a bugfix, scope/codebase notes for a feature)
- depth: one of "skip" | "shallow" | "full" | "extensive", set by Linus in his scope call. Linus decides which level this work needs

ensures:
- plan: the agreed approach — ranges from Prime's direct proposal (skip) to a multi-perspective adversarial-tested plan (extensive), depending on depth

strategies:
- when depth is "skip": Prime proposes, that is the plan
- when depth is "shallow": Prime proposes, Linus reviews, one revision round if needed
- when depth is "full": Prime proposes, Linus challenges, Prime defends, Linus decides
- when depth is "extensive": Prime and Theo propose in parallel, then cross-review each other in parallel, then Linus synthesizes with equal weight on both
- Linus has the final word at every depth level

### Execution

# === SKIP ===
if depth is "skip":
  let plan = call prime
    task: "propose your approach"
    topic: topic
    context: context
  return plan

# === SHALLOW ===
if depth is "shallow":
  let proposal = call prime
    task: "propose your approach"
    topic: topic
    context: context
  let review = call linus
    task: "review Prime's proposal. Accept it or send back specific notes."
    topic: topic
    context: context
    proposal: proposal
  if review accepts the proposal:
    return proposal
  let plan = call prime
    task: "revise your proposal based on Linus's notes"
    proposal: proposal
    review: review
  return plan

# === FULL ===
if depth is "full":
  let proposal = call prime
    task: "explore the relevant code, then propose your approach with reasoning"
    topic: topic
    context: context
  let challenge = call linus
    task: "challenge Prime's proposal — find every weakness"
    topic: topic
    context: context
    proposal: proposal
  let defense = call prime
    task: "respond to Linus's challenges"
    topic: topic
    proposal: proposal
    challenge: challenge
  let plan = call linus
    task: "decide the final approach"
    topic: topic
    proposal: proposal
    challenge: challenge
    defense: defense
  return plan

# === EXTENSIVE ===
# Round 1: Prime and Theo propose in parallel — each from their own angle
parallel:
  let prime-proposal = call prime
    task: "propose your approach from an implementation perspective"
    topic: topic
    context: context
  let theo-proposal = call theo
    task: "propose your approach from a testing and user-experience perspective"
    topic: topic
    context: context

# Round 1 cross-review: each critiques the other in parallel
parallel:
  let prime-on-theo = call prime
    task: "review Theo's proposal"
    prime-proposal: prime-proposal
    theo-proposal: theo-proposal
  let theo-on-prime = call theo
    task: "review Prime's proposal"
    prime-proposal: prime-proposal
    theo-proposal: theo-proposal

# Round 2: both revise in parallel — informed by the cross-reviews
parallel:
  let prime-revised = call prime
    task: "revise your proposal based on Theo's critique"
    prime-proposal: prime-proposal
    theo-on-prime: theo-on-prime
  let theo-revised = call theo
    task: "revise your proposal based on Prime's critique"
    theo-proposal: theo-proposal
    prime-on-theo: prime-on-theo

# Round 2 cross-review: final critique of the revised proposals in parallel
parallel:
  let prime-final-review = call prime
    task: "review Theo's revised proposal"
    prime-revised: prime-revised
    theo-revised: theo-revised
  let theo-final-review = call theo
    task: "review Prime's revised proposal"
    prime-revised: prime-revised
    theo-revised: theo-revised

# Linus synthesizes — sees both rounds, both perspectives carry equal weight
let plan = call linus
  task: "synthesize both perspectives and decide the final approach — neither outranks the other"
  topic: topic
  context: context
  prime-revised: prime-revised
  theo-revised: theo-revised
  prime-final-review: prime-final-review
  theo-final-review: theo-final-review

return plan
