MO D U L E S P E C I F I C A T I O N

## Vocabulary

Final Decisions & Flow

Level and Subskill as two dimensions. Diagnose, teach what is needed, prove the improvement.

Assess → Learn → Practice → Re-assess → Review → Progress


## CONTENTS

## Document Overview


## SECT ION 0 1

## Overall Architecture

Vocabulary uses two dimensions:

Vocabulary

│

├── Level 1 — Foundation

├── Level 2 — Developing

├── Level 3 — Intermediate

└── Level 4 — Advanced

## Roles

- Level → determines curriculum progression and vocabulary difficulty.

- Subskill → determines the learner's vocabulary competency and weaknesses.

- The same subskills can appear at multiple levels, but the words, contexts, and complexity change.

Do not use Easy / Medium / Hard as learner-facing levels.

The architecture should be data-driven so Level 5/6 can be added later without redesigning the UX.

## SECT ION 02

## Vocabulary Subskills

The vocabulary curriculum is organized around competency areas.

## A practical V1 set:

- 1. Word Meaning / Contextual Meaning

- 2. Word Usage

- 3. Synonyms & Antonyms

- 4. Collocations

- 5. Phrasal Verbs

- 6. Word Formation

Not every subskill needs equal amounts of content at every level.


For example:

```
Level 1:
Word Meaning → high importance
Phrasal Verbs → limited
Level 4:
Word Meaning → still important
Phrasal Verbs → much more important
Collocations → much more important
```

## SECT ION 03

## Vocabulary Pre-Assessment

## Purpose

The pre-assessment answers two questions:

```
1. What vocabulary level is the learner currently at?
2. Which vocabulary subskills need improvement?
```

It is not intended to test every word.

## Base assessment

Use approximately:

```
5 questions × 4 levels = 20 possible questions
```

At each level:

```
Level 1
Q1 → Subskill A
Q2 → Subskill B
Q3 → Subskill C
Q4 → Subskill D
Q5 → Subskill E
Level 2
Q1 → Subskill A
...
```

So every level gets coverage across the important subskills.


## Adaptive progression

The learner does not necessarily need to answer all 20.

```
Level 1
↓
5 questions
↓
Strong enough?
├── Yes → Level 2
└── No → current ability around Level 1
```

Then:

```
Level 2
↓
5 questions
↓
Strong enough?
├── Yes → Level 3
└── No → current ability around Level 2
```

And so on.

## Borderline case

If performance is unclear:

```
5 questions
↓
Borderline
↓
1–2 additional questions
↓
Better evidence
```

This prevents one lucky/unlucky answer from determining the level.


## SECT ION 04

## Question Metadata

Every vocabulary assessment item should contain:

```
Question
├── Level
├── Subskill
├── Difficulty
└── Question Type
```

## Example:

```
Question:
"She was reluctant to accept the offer."
Level: 3
Subskill: Word Usage
Difficulty: Medium
Type: Multiple Choice
```

This allows EngCoach to calculate both:

```
Overall Level
+
Subskill Competency Profile
```

## SECT ION 05

## Do NOT Use One Correct Answer as Mastery

## One correct answer only means:

The learner got this particular item correct.

It does not mean:

The learner has mastered this subskill.

## Therefore:

```
1 question → signal
Multiple questions → stronger evidence
Repeated learning + practice + post-assessment → mastery evidence
```


For Vocabulary, use learner-facing competency states such as:

rather than immediately calling a subskill "Mastered."

## SECT ION 06

## Pre-Assessment Result

## Example:

This becomes the basis for personalization.

## SECT ION 07

## Personalized Vocabulary Path

The system should not make the learner study everything again.

## Instead:

```
Pre-Assessment
↓
Identify comfortable areas
↓
Identify weak areas
↓
Create focused path
```


## Example:

```
Level 3 — Intermediate
Focus Areas:
1. Collocations
2. Phrasal Verbs
3. Synonyms & Antonyms
Skip / Reduce:
✓ Word Meaning
✓ Word Usage
```

The learner can therefore spend more time where they actually need it.

## SECT ION 08

## Vocabulary Learning Content

Your original idea was:

Bangla meaning + example + Bangla translation + synonym + antonym.

We refined it to:

```
Vocabulary Card
│
├── Word
├── Bangla meaning
├── Part of speech [when relevant]
├── Example sentence
│ └── Bangla translation
├── Usage / Context [when relevant]
├── Synonyms
├── Antonyms
└── Collocations [when relevant]
```

## Important principle

Not every card needs every field.

For example, some words need detailed usage information; others don't.

Avoid information overload.


## Example

```
RELUCTANT
Adjective
Bangla:
Example:
He was reluctant to accept the offer.
Usage:
reluctant + to + verb
Synonyms:
unwilling, hesitant
Antonyms:
willing, eager
Common expression:
reluctant to agree
```

The goal isn't simply:

"Memorize reluctant = ."

It is:

Understand the word + recognize it + know how it behaves + use it.

## SECT ION 09

## Learning Content Should Be Chunked

Do not present 30–40 vocabulary cards continuously.


Instead:

```
Learning Chunk
↓
5–10 vocabulary cards
↓
Short Practice
↓
Next Learning Chunk
↓
5–10 vocabulary cards
↓
Short Practice
↓
...
```

The 5–10 is a guideline, not a rigid rule.

The actual chunk size can depend on:

- number of words

- complexity

- topic/context

## SECT ION 1 0

## Vocabulary Practice

Practice follows the recently learned vocabulary.

The general progression is:

- learner level

- subskill

- cognitive load

```
Recognition
↓
Understanding
↓
Usage
↓
Recall
↓
Production
```

## Practice types

- 1. Meaning Recognition

What does reluctant mean?


## 2. Contextual Meaning

Rafi was reluctant to join the competition because he was nervous.

What does reluctant mean here?

## 3. Correct Usage

Which sentence uses reluctant correctly?

## 4. Synonym / Antonym

Which word is closest in meaning to reluctant?

## 5. Collocation

She was reluctant ___ accept the offer.

to ✓

## 6. Recall / Production

Complete: She was reluctant to ______.

or eventually:

Make a sentence using "reluctant."

Production can be used selectively, especially at higher levels.

## SECT ION 1 1

## Practice Is Adaptive

You don't need:

Every lesson = exactly 10 questions


Instead:

```
Simple lesson
→ 3–5 practice questions
More difficult lesson
→ 5–8 questions
Weak subskill
→ more questions targeting that subskill
```

So practice is determined by learning content + learner needs.

## SECT ION 1 2

## Practice Feedback

Practice provides immediate feedback.

Example:

```
Q:
She was reluctant ___ accept the offer.
Learner:
accept ✗
Feedback:
Not quite.
We use:
reluctant + to + verb
Example:
She was reluctant to accept the offer.
Try another one.
```

The learner gets another opportunity to apply the concept.


## Learning Loop

The core Vocabulary learning loop becomes:

Learn 5–10 words

↓

Practice

↓

Feedback

↓

Learn next 5–10 words

↓

Practice

↓

Feedback

↓

...

↓

Review / Recall

This is much better than:

```
30 cards → 20 questions
```

because the learner retrieves recently learned words while they're still fresh.

## SECT ION 1 4

## Practice Should Reflect the Weak Subskill

Suppose the pre-assessment says:

Collocations → Needs Practice

Then the personalized lesson should emphasize:

```
Learn:
word + common collocations
Practice:
choose correct collocation
complete collocation
identify incorrect combination
use collocation in context
```


## If the weakness is Contextual Meaning:

```
Learn:
word + multiple contextual examples
Practice:
infer meaning from sentence
choose appropriate word
distinguish similar words
```

Therefore:

The pre-assessment directly influences both the content and the practice.

## SECT ION 1 5

## Post-Assessment

The same overall philosophy applies to Post-Assessment.

But:

Do not repeat the exact pre-assessment questions.

Use:

Same:

Level

Subskill

Difficulty range

Question types

Different:

Words

Sentences

Questions

Contexts

This measures whether the learner can actually apply what they learned.


## SECT ION 1 6

## Post-Assessment Purpose

## Post-assessment measures:

## Then compare:

This gives the learner evidence of improvement.


## SECT ION 1 7

## Vocabulary Outcome

Example:

```
L EVE L 3 — STRONG PROGR E SS
You strengthened the areas that needed the most practice.
B E FOR E → AF T E R
Collocations
Phrasal Verbs
Synonyms & Antonyms
```

## Then:

```
Next Step
✓ Continue Level 3
or
→ Ready to check Level 4
```

The actual decision comes from the assessment data, not a manually selected UI state.

```
43% →
78% ↑
38% →
72% ↑
65% →
81% ↑
```


## Complete Vocabulary Flow

This is the final high-level flow I would use:


## The core philosophy

| LEVEL SUBSKILL ASSESSMENT LEARNING PRACTICE POST-ASSESSMENT OUTCOME | How advanced is the learner? What vocabulary ability needs work? Diagnose Teach Build ability Measure improvement Show evidence + decide next step |
| --- | --- |

This gives Vocabulary its own adaptive identity, while still following the same overall EngCoach principle as Grammar:

Assess → Learn → Practice → Re-assess → Review → Progress.
