---
name: metaphor-stock
description: >-
  Picks at most one metaphor after the two real things are named, and rejects
  default English place stock (room, door, lock, wall, house, boundary). Load
  when a reply or draft is about to explain with a picture, when comparing
  idioms across languages, or when rooms and doors keep showing up.
---

# Metaphor stock

## When to load

Load when a user-facing reply or a prose draft is about to use a metaphor, when the human asks to compare idioms across languages, or when English place stock (room, door, lock, wall, house, boundary, threshold) showed up as a stand-in.

The always-on chat rule already requires a picture-free sentence first. This skill chooses the picture, or drops it.

A real object already in the thread is not stock. A clinic door in a piece about clinics stays. "Different room" for chat versus the essays is stock.

## Place stock

English place stock, used as a picture of a situation:

- room, another room, in the room
- door, front door, threshold
- lock, key (as a picture; a real API key or door key in the thread is not stock)
- wall, house, building
- boundary

**CONSTRAINT:** MUST NOT ship a translation of that stock into another language and call it a new metaphor.

- Enforcement: If the candidate is "puerta", "Tür", or "porte" standing in for a situation that has no door, Decision is REJECT stock.
- Violation: STOP, drop the candidate, rerun the gate.

CORRECT:
```text
Spanish: el mismo perro con distinto collar.
The habit stayed. Only the name-tag moved.
```

PROHIBITED:
```text
Spanish: la misma habitación, otra puerta.
```

## Steps

1. Write one sentence that names the two real things and what they share. No picture in that sentence.
2. Write the one job the picture must do, in the human's words.
3. Complete the gate in the next section for every candidate before any candidate is written into the reply.
4. Ship at most one candidate whose Decision is USE. If none is USE, ship step 1 and no picture.

## Gate

```text
Candidate: [idiom or image, in its own language when it is not English]
Already how that language talks: YES: [the idiom as people say it] / NO
Job match: YES: [quote the one job from step 2] / NO
Place stock: YES: [the stock word] / NO
Decision: USE | REJECT stock | REJECT job
If USE: Picture: [one sentence that still names the two things]
```

**CONSTRAINT:** MUST complete the gate before any metaphor appears in the reply. MUST limit Decision to USE, REJECT stock, or REJECT job.

- Enforcement: The draft contains the picture-free sentence from step 1. At most one picture follows, and that picture's gate has Job match YES, Place stock NO, and Already how that language talks YES.
- Violation: STOP, delete extra pictures and any candidate that failed the gate.

CORRECT:
```text
Candidate: el mismo perro con distinto collar
Already how that language talks: YES: Spanish already says this for "same thing, new label"
Job match: YES: same habit, two names (chat and the essays)
Place stock: NO
Decision: USE
If USE: Picture: Chat and the essays used the same habit; Spanish would call that the same dog with a different collar.
```

PROHIBITED:
```text
Candidate: different room
Decision: USE
```

**CONSTRAINT:** MUST ship at most one picture. MUST keep the picture-free sentence even when a picture ships.

- Enforcement: Count metaphors in the reply. Zero or one. The two real things are named in a sentence that has none of the place-stock words.
- Violation: STOP, cut to one picture or to the plain sentence.

## Pre-completion checklist

- [ ] **Plain sentence first:** the two real things are named with no picture
      Method: Read the sentence that introduces the pair
      Pass: no place-stock word and no idiom in that sentence
      Fail: STOP, rewrite that sentence, then rerun the gate
- [ ] **One picture or none:** zero or one metaphor after that sentence
      Method: Count idioms and stock images
      Pass: 0 or 1, and the one has Decision USE
      Fail: STOP, delete the extras
- [ ] **Not a translated door:** the picture is not place stock in another language
      Method: Read Already how that language talks
      Pass: YES quotes an idiom people already use for this job
      Fail: STOP, REJECT stock
