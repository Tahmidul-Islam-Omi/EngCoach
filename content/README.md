# Curriculum content

Human-authored source of truth (SPEC §4.1). Reviewed in pull requests, then
uploaded to Firestore by `tools/seed_content.dart`. The app only ever reads
Firestore — it never bundles these files.

One JSON file per topic. One Firestore document per topic, so loading a topic
costs a single read.

## Shape

```
topic
├── meta              id, title, summary, whyThisTopic, order
├── assessmentConfig  how many to draw, and the qualifying score
├── subSkills[]       the units a pre-assessment scores against
│   ├── preAssessmentBank[]   6 questions — 3 drawn at random
│   └── postAssessmentBank[]  6 DIFFERENT questions — 3 drawn
└── lessons[]         one per subSkill
    ├── blocks[]      the rendered lesson content
    └── practice[]    questions with per-option feedback
```

## Rules that matter

- **Banks live inside their sub-skill**, so questions are never mistagged and
  "draw 3 for this sub-skill" is a local operation.
- **Pre and post banks must not share questions.** If they do, the
  improvement number measures memory, not learning. The validator checks
  both directions — a pre-test answer reappearing as a post-test *distractor*
  is the worst case, because the learner has already seen it endorsed.
- **Each bank holds 6 questions and the app draws 3.** Two learners get
  different checks, and the same learner retaking one rarely sees the same
  set — so a score reflects the sub-skill, not a memorised answer. Raise
  `bankSize` once real usage shows whether 6 is enough.
- **Pre and post banks must cover the same rules in the same proportion.**
  Every question carries a `rule` tag for exactly this reason. If the pre-test
  includes hard irregulars and the post-test doesn't, scores rise because the
  second paper was easier — and the improvement figure, which is the whole
  product claim, becomes a lie.
- **All 3 correct qualifies the learner to skip that sub-skill**
  (`qualifyingScore`). Anything less prioritises it.
- **Every wrong option carries its own `feedback`.** Authored, not generated
  — the app makes no AI call to explain a wrong answer.
- **Feedback must not describe a fix that lands on another wrong option.**
  No validator can catch this; read every distractor's advice and apply it.
  "*She needing more time*" → "it needs **is** in front of it" is wrong when
  "*She is needing more time*" is option (d) of the same question.
- **Every distractor must actually be wrong.** Watch for options that are
  valid English in another reading — "The shop isn't **open** today" is a
  perfectly good sentence, so it can't be the wrong answer to "which sentence
  is correct?".
- **Assessments test only what the topic taught.** Present continuous for a
  future arrangement ("Are the guests arriving tonight?") is real English,
  but no lesson here covers it, so it can't be a right answer either.
- **`bn` is optional on feedback, required on the lesson's bangla block.**
  Grammar terms stay in English inside Bangla sentences.
- **Inline `**bold**`** is the only markup allowed in text fields.

## Block types

| type | renders as |
|---|---|
| `text` | a paragraph |
| `pattern` | the boxed rule with a highlighted tail |
| `table` | two-column comparison |
| `examples` | list of sentences, one word highlighted |
| `callout` | "WATCH OUT" style note |
| `bangla` | the Bangla explanation block |
