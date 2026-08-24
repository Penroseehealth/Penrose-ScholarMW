from sqlalchemy import select

from app.database.engine import async_session
from app.models.languages import (
    Language,
    LanguageGrammarRule,
    LanguageLesson,
    LanguageLevel,
    LanguageUnit,
    LanguageVocabulary,
)


async def seed_english():
    async with async_session() as db:
        existing = await db.execute(select(Language).where(Language.slug == "english"))
        if existing.scalar_one_or_none():
            return

        lang = Language(
            name="English",
            slug="english",
            native_name="English",
            icon="🇬🇧",
            color="#2563EB",
            level_system="Form-based progression to academic English",
            description="Complete English language learning from foundation to academic proficiency",
        )
        db.add(lang)
        await db.flush()

        levels_data = [
            (
                "Foundation",
                "foundation",
                "Form 1",
                "English Foundation",
                "Build a strong foundation in English basics",
                [
                    (
                        "Parts of Speech",
                        "Core building blocks of English",
                        [
                            (
                                "Nouns & Pronouns",
                                "Types of nouns and pronoun usage",
                                "grammar",
                                [
                                    (
                                        "noun",
                                        "noun",
                                        "A word that names a person, place, thing, or idea",
                                        "n",
                                        "cat, school, happiness",
                                        "The cat sat on the mat.",
                                        "nouns_basic",
                                    ),
                                    (
                                        "proper noun",
                                        "noun",
                                        "A specific name for a particular person, place, or thing, always capitalised",
                                        "n",
                                        "London, Monday, Sarah",
                                        "London is the capital of England.",
                                        "nouns_basic",
                                    ),
                                    (
                                        "pronoun",
                                        "noun",
                                        "A word that replaces a noun to avoid repetition",
                                        "pronoun",
                                        "he, she, it, they",
                                        "She went to the store.",
                                        "pronouns",
                                    ),
                                    (
                                        "personal pronoun",
                                        "noun",
                                        "A pronoun that refers to a specific person or thing",
                                        "pronoun",
                                        "I, you, he, she, it, we, they",
                                        "They are my friends.",
                                        "pronouns",
                                    ),
                                ],
                            ),
                            (
                                "Verbs & Adjectives",
                                "Action words and descriptive words",
                                "grammar",
                                [
                                    (
                                        "verb",
                                        "verb",
                                        "A word that expresses an action or state of being",
                                        "v",
                                        "run, eat, think, is",
                                        "She runs every morning.",
                                        "verbs",
                                    ),
                                    (
                                        "adjective",
                                        "adjective",
                                        "A word that describes or modifies a noun",
                                        "adj",
                                        "big, blue, happy, tall",
                                        "The tall man wore a blue hat.",
                                        "adjectives",
                                    ),
                                    (
                                        "adverb",
                                        "adverb",
                                        "A word that modifies a verb, adjective, or another adverb",
                                        "adv",
                                        "quickly, very, never, well",
                                        "He runs quickly.",
                                        "adverbs",
                                    ),
                                ],
                            ),
                            (
                                "Articles & Prepositions",
                                "Small but essential words",
                                "grammar",
                                [
                                    (
                                        "article",
                                        "determiner",
                                        "A word used before a noun to indicate definiteness",
                                        "det",
                                        "a, an, the",
                                        "A cat is sleeping. The cat is black.",
                                        "articles",
                                    ),
                                    (
                                        "preposition",
                                        "preposition",
                                        "A word showing the relationship between a noun and other words",
                                        "prep",
                                        "in, on, at, under, between",
                                        "The book is on the table.",
                                        "prepositions",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Basic Sentences",
                        "Forming complete thoughts",
                        [
                            (
                                "Simple Sentences",
                                "Subject-verb-object structure",
                                "grammar",
                                [
                                    (
                                        "sentence",
                                        "structure",
                                        "A complete thought with a subject and predicate",
                                        "s",
                                        "The dog barked.",
                                        "Simple sentences have one independent clause.",
                                        "sentence_structure",
                                    ),
                                    (
                                        "subject",
                                        "structure",
                                        "The person or thing that performs the action",
                                        "n",
                                        "The boy kicked the ball.",
                                        "The boy is the subject.",
                                        "sentence_structure",
                                    ),
                                ],
                            ),
                            (
                                "Questions & Negation",
                                "Asking and denying",
                                "grammar",
                                [
                                    (
                                        "question",
                                        "structure",
                                        "A sentence that asks for information",
                                        "s",
                                        "Where are you going?",
                                        "Questions use auxiliary verbs before the subject.",
                                        "sentence_structure",
                                    ),
                                    (
                                        "negation",
                                        "structure",
                                        "Expressing the opposite or absence of something",
                                        "s",
                                        "She does not like coffee.",
                                        "Use not after an auxiliary verb.",
                                        "sentence_structure",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Everyday Words",
                        "Common vocabulary for daily life",
                        [
                            (
                                "Greetings",
                                "Polite expressions",
                                "grammar",
                                [
                                    (
                                        "hello",
                                        "excl",
                                        "A common greeting",
                                        "interj",
                                        "Hello, how are you?",
                                        "Hello is used in both formal and informal settings.",
                                        "greetings",
                                    ),
                                    (
                                        "please",
                                        "excl",
                                        "A polite way to make a request",
                                        "interj",
                                        "Please pass the salt.",
                                        "Please shows courtesy.",
                                        "greetings",
                                    ),
                                    (
                                        "thank you",
                                        "excl",
                                        "An expression of gratitude",
                                        "interj",
                                        "Thank you for your help.",
                                        "Thank you is polite and widely used.",
                                        "greetings",
                                    ),
                                    (
                                        "goodbye",
                                        "excl",
                                        "A farewell greeting",
                                        "interj",
                                        "Goodbye, see you tomorrow!",
                                        "Goodbye is formal; bye is informal.",
                                        "greetings",
                                    ),
                                ],
                            ),
                            (
                                "Numbers & Time",
                                "Counting and time expressions",
                                "grammar",
                                [
                                    (
                                        "number",
                                        "noun",
                                        "A mathematical unit used for counting",
                                        "n",
                                        "one, two, three, hundred",
                                        "There are three books on the table.",
                                        "numbers",
                                    ),
                                    (
                                        "time",
                                        "noun",
                                        "The ongoing sequence of events",
                                        "n",
                                        "morning, afternoon, night",
                                        "What time is it?",
                                        "time",
                                    ),
                                ],
                            ),
                            (
                                "Family & People",
                                "People in your life",
                                "grammar",
                                [
                                    (
                                        "mother",
                                        "noun",
                                        "A female parent",
                                        "n",
                                        "My mother is a teacher.",
                                        "Mother is a common noun.",
                                        "family",
                                    ),
                                    (
                                        "father",
                                        "noun",
                                        "A male parent",
                                        "n",
                                        "My father works at the hospital.",
                                        "Father is a common noun.",
                                        "family",
                                    ),
                                    (
                                        "friend",
                                        "noun",
                                        "A person you know well and like",
                                        "n",
                                        "She is my best friend.",
                                        "Friend can be used for any close companion.",
                                        "family",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
            (
                "Elementary",
                "elementary",
                "Form 2",
                "Elementary / Pre-Intermediate",
                "Develop core English skills",
                [
                    (
                        "Verb Tenses",
                        "When actions happen",
                        [
                            (
                                "Present Simple & Continuous",
                                "Habitual and ongoing actions",
                                "grammar",
                                [
                                    (
                                        "present simple",
                                        "tense",
                                        "Used for habits, facts, and general truths",
                                        "v",
                                        "I work every day. The sun rises in the east.",
                                        "Use base form for I/you/we/they; add -s for he/she/it.",
                                        "verb_tenses",
                                    ),
                                    (
                                        "present continuous",
                                        "tense",
                                        "Used for actions happening right now",
                                        "v",
                                        "I am studying English.",
                                        "Use am/is/are + verb-ing.",
                                        "verb_tenses",
                                    ),
                                ],
                            ),
                            (
                                "Past Simple",
                                "Completed past actions",
                                "grammar",
                                [
                                    (
                                        "past simple",
                                        "tense",
                                        "Used for completed actions in the past",
                                        "v",
                                        "I visited London last summer.",
                                        "Regular verbs add -ed; irregular verbs change form.",
                                        "verb_tenses",
                                    ),
                                    (
                                        "irregular verb",
                                        "verb",
                                        "A verb that does not follow the -ed pattern",
                                        "v",
                                        "go/went/gone, eat/ate/eaten, see/saw/seen",
                                        "Irregular verbs must be memorised.",
                                        "verb_tenses",
                                    ),
                                ],
                            ),
                            (
                                "Future Forms",
                                "Expressing future time",
                                "grammar",
                                [
                                    (
                                        "will",
                                        "modal",
                                        "Expresses future predictions, promises, and decisions",
                                        "v",
                                        "I will call you tomorrow.",
                                        "Will is used for spontaneous decisions and predictions.",
                                        "verb_tenses",
                                    ),
                                    (
                                        "going to",
                                        "structure",
                                        "Expresses planned future actions",
                                        "s",
                                        "I am going to study medicine.",
                                        "Use am/is/are + going to + base verb.",
                                        "verb_tenses",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Sentence Building",
                        "Creating more complex ideas",
                        [
                            (
                                "Compound Sentences",
                                "Joining equal ideas",
                                "grammar",
                                [
                                    (
                                        "conjunction",
                                        "conjunction",
                                        "A word that connects clauses or sentences",
                                        "conj",
                                        "and, but, or, so, yet",
                                        "I wanted to go, but it was raining.",
                                        "sentence_structure",
                                    ),
                                    (
                                        "compound sentence",
                                        "structure",
                                        "Two independent clauses joined by a conjunction",
                                        "s",
                                        "She studied hard, and she passed the exam.",
                                        "Use a comma before the conjunction.",
                                        "sentence_structure",
                                    ),
                                ],
                            ),
                            (
                                "Complex Sentences",
                                "Main and dependent ideas",
                                "grammar",
                                [
                                    (
                                        "subordinate clause",
                                        "structure",
                                        "A dependent clause that cannot stand alone",
                                        "s",
                                        "Although it was raining, we went out.",
                                        "Subordinate clauses begin with words like although, because, when.",
                                        "sentence_structure",
                                    ),
                                    (
                                        "relative clause",
                                        "structure",
                                        "A clause that modifies a noun",
                                        "s",
                                        "The man who called is my uncle.",
                                        "Use who for people, which for things, that for both.",
                                        "sentence_structure",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Communication",
                        "Real-world English skills",
                        [
                            (
                                "Describing Things",
                                "Adjectives and adverbs in use",
                                "grammar",
                                [
                                    (
                                        "comparative",
                                        "adjective",
                                        "The form of an adjective used to compare two things",
                                        "adj",
                                        "bigger, more beautiful, faster",
                                        "Use -er for short adjectives; more for long adjectives.",
                                        "adjectives",
                                    ),
                                    (
                                        "superlative",
                                        "adjective",
                                        "The form of an adjective used for the highest degree",
                                        "adj",
                                        "biggest, most beautiful, fastest",
                                        "Use -est for short adjectives; most for long adjectives.",
                                        "adjectives",
                                    ),
                                ],
                            ),
                            (
                                "Making Requests",
                                "Polite expressions",
                                "grammar",
                                [
                                    (
                                        "could",
                                        "modal",
                                        "A polite way to make requests",
                                        "modal",
                                        "Could you help me, please?",
                                        "Could is more polite than can.",
                                        "professional",
                                    ),
                                    (
                                        "would",
                                        "modal",
                                        "Used for polite offers and requests",
                                        "modal",
                                        "Would you like some tea?",
                                        "Would is used in formal situations.",
                                        "professional",
                                    ),
                                ],
                            ),
                            (
                                "Directions & Places",
                                "Navigating spaces",
                                "grammar",
                                [
                                    (
                                        "direction",
                                        "noun",
                                        "The course along which someone moves",
                                        "n",
                                        "Turn left at the traffic light.",
                                        "Left, right, straight, opposite.",
                                        "travel",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
            (
                "Intermediate",
                "intermediate",
                "Form 3",
                "Intermediate",
                "Refine grammar and develop writing",
                [
                    (
                        "Advanced Grammar",
                        "Sophisticated structures",
                        [
                            (
                                "Conditionals",
                                "If-clauses and hypotheticals",
                                "grammar",
                                [
                                    (
                                        "zero conditional",
                                        "structure",
                                        "Used for general truths and scientific facts",
                                        "s",
                                        "If you heat water to 100°C, it boils.",
                                        "Use present simple in both clauses.",
                                        "conditionals",
                                    ),
                                    (
                                        "first conditional",
                                        "structure",
                                        "Used for real future possibilities",
                                        "s",
                                        "If it rains, I will take an umbrella.",
                                        "Use present simple in the if-clause, will + base verb in the main clause.",
                                        "conditionals",
                                    ),
                                    (
                                        "second conditional",
                                        "structure",
                                        "Used for unreal or unlikely present situations",
                                        "s",
                                        "If I had more money, I would travel the world.",
                                        "Use past simple in the if-clause, would + base verb in the main clause.",
                                        "conditionals",
                                    ),
                                    (
                                        "third conditional",
                                        "structure",
                                        "Used for past situations that did not happen",
                                        "s",
                                        "If I had studied harder, I would have passed.",
                                        "Use past perfect in the if-clause, would have + past participle in the main clause.",
                                        "conditionals",
                                    ),
                                ],
                            ),
                            (
                                "Passive Voice",
                                "Changing focus from doer to receiver",
                                "grammar",
                                [
                                    (
                                        "passive voice",
                                        "structure",
                                        "A sentence where the subject receives the action",
                                        "s",
                                        "The cake was eaten by the children.",
                                        "Use be + past participle. The agent (by whom) is optional.",
                                        "passive_voice",
                                    ),
                                ],
                            ),
                            (
                                "Reported Speech",
                                "Relaying what others said",
                                "grammar",
                                [
                                    (
                                        "reported speech",
                                        "structure",
                                        "Reporting someone else's words indirectly",
                                        "s",
                                        "She said that she was tired.",
                                        "Tense shifts back: said + that + past tense.",
                                        "reported_speech",
                                    ),
                                    (
                                        "direct speech",
                                        "structure",
                                        "Quoting someone's exact words",
                                        "s",
                                        "He said, 'I am coming.'",
                                        "Use quotation marks and present tense if still true.",
                                        "reported_speech",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Writing",
                        "Expressing ideas in text",
                        [
                            (
                                "Paragraph Writing",
                                "Organised written text",
                                "grammar",
                                [
                                    (
                                        "topic sentence",
                                        "structure",
                                        "The first sentence of a paragraph that states the main idea",
                                        "s",
                                        "Exercise is important for good health.",
                                        "Every paragraph should begin with a clear topic sentence.",
                                        "writing",
                                    ),
                                    (
                                        "supporting detail",
                                        "structure",
                                        "Evidence or examples that support the topic sentence",
                                        "s",
                                        "It helps prevent diseases and improves mood.",
                                        "Use specific examples and facts.",
                                        "writing",
                                    ),
                                ],
                            ),
                            (
                                "Formal Letters",
                                "Professional correspondence",
                                "grammar",
                                [
                                    (
                                        "formal letter",
                                        "structure",
                                        "A letter written in professional or official language",
                                        "s",
                                        "Dear Sir/Madam, I am writing to enquire about...",
                                        "Use formal salutations and sign-offs.",
                                        "professional",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Reading",
                        "Comprehending texts",
                        [
                            (
                                "Reading Comprehension",
                                "Understanding written texts",
                                "grammar",
                                [
                                    (
                                        "main idea",
                                        "structure",
                                        "The central point or message of a text",
                                        "s",
                                        "The main idea of the article is that climate change affects agriculture.",
                                        "Identify the topic sentence for the main idea.",
                                        "academic",
                                    ),
                                    (
                                        "inference",
                                        "structure",
                                        "A conclusion reached from evidence and reasoning",
                                        "s",
                                        "The text implies that the author supports renewable energy.",
                                        "Inferences require reading between the lines.",
                                        "academic",
                                    ),
                                ],
                            ),
                            (
                                "Critical Reading",
                                "Evaluating texts",
                                "grammar",
                                [
                                    (
                                        "argument",
                                        "structure",
                                        "A reason given in support of an idea",
                                        "s",
                                        "The argument for renewable energy is strong.",
                                        "Look for evidence and logical reasoning.",
                                        "academic",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
            (
                "Upper Intermediate",
                "upper-intermediate",
                "Form 4",
                "Upper Intermediate",
                "Master complex English structures",
                [
                    (
                        "Academic Skills",
                        "University-level English",
                        [
                            (
                                "Essay Writing",
                                "Structured academic writing",
                                "grammar",
                                [
                                    (
                                        "thesis statement",
                                        "structure",
                                        "The main argument of an essay stated in one sentence",
                                        "s",
                                        "This essay argues that education is the key to economic development.",
                                        "Place the thesis at the end of the introduction.",
                                        "writing",
                                    ),
                                    (
                                        "essay structure",
                                        "structure",
                                        "The organisation of an academic essay",
                                        "s",
                                        "Introduction, body paragraphs, conclusion.",
                                        "Each body paragraph should support the thesis.",
                                        "writing",
                                    ),
                                ],
                            ),
                            (
                                "Presentation Skills",
                                "Spoken academic English",
                                "grammar",
                                [
                                    (
                                        "signposting",
                                        "structure",
                                        "Language that guides the listener through a presentation",
                                        "s",
                                        "First, I will discuss... Then, I will examine... Finally, I will conclude...",
                                        "Use clear transitions to help the audience follow.",
                                        "professional",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Advanced Grammar",
                        "Refined structures",
                        [
                            (
                                "Relative Clauses",
                                "Adding detail to nouns",
                                "grammar",
                                [
                                    (
                                        "defining relative clause",
                                        "structure",
                                        "A clause that identifies which noun is meant",
                                        "s",
                                        "The book that I borrowed was excellent.",
                                        "Use that, which, who, whom, whose.",
                                        "sentence_structure",
                                    ),
                                    (
                                        "non-defining relative clause",
                                        "structure",
                                        "A clause that adds extra information",
                                        "s",
                                        "My brother, who lives in London, is visiting.",
                                        "Use commas. Do not use 'that'.",
                                        "sentence_structure",
                                    ),
                                ],
                            ),
                            (
                                "Modal Verbs",
                                "Expressing possibility and obligation",
                                "grammar",
                                [
                                    (
                                        "must",
                                        "modal",
                                        "Strong obligation or logical certainty",
                                        "modal",
                                        "You must submit the form by Friday. She must be tired.",
                                        "Must expresses strong necessity or deduction.",
                                        "verb_tenses",
                                    ),
                                    (
                                        "should",
                                        "modal",
                                        "Advice or recommendation",
                                        "modal",
                                        "You should exercise regularly.",
                                        "Should is softer than must.",
                                        "verb_tenses",
                                    ),
                                    (
                                        "might",
                                        "modal",
                                        "Possibility or uncertainty",
                                        "modal",
                                        "It might rain later.",
                                        "Might expresses less certainty than will.",
                                        "verb_tenses",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Professional",
                        "Workplace English",
                        [
                            (
                                "Business English",
                                "Workplace communication",
                                "grammar",
                                [
                                    (
                                        "meeting",
                                        "noun",
                                        "A formal discussion to reach a decision",
                                        "n",
                                        "Let us schedule a meeting for next week.",
                                        "Business meetings use formal language.",
                                        "professional",
                                    ),
                                    (
                                        "deadline",
                                        "noun",
                                        "The latest time something must be completed",
                                        "n",
                                        "The deadline for the report is Monday.",
                                        "Meeting deadlines is essential in business.",
                                        "professional",
                                    ),
                                ],
                            ),
                            (
                                "Formal Correspondence",
                                "Professional letters and emails",
                                "grammar",
                                [
                                    (
                                        "email",
                                        "noun",
                                        "A written message sent electronically",
                                        "n",
                                        "I sent an email to the manager.",
                                        "Professional emails use formal language and clear structure.",
                                        "professional",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
            (
                "Advanced",
                "advanced",
                "Advanced I",
                "Advanced English",
                "Achieve near-native proficiency",
                [
                    (
                        "Mastery Grammar",
                        "Expert-level structures",
                        [
                            (
                                "Subjunctive Mood",
                                "Hypothetical and formal expressions",
                                "grammar",
                                [
                                    (
                                        "subjunctive",
                                        "mood",
                                        "A verb form used for hypothetical or contrary-to-fact situations",
                                        "v",
                                        "If I were you, I would accept the offer.",
                                        "Use were (not was) for all subjects in the subjunctive.",
                                        "conditionals",
                                    ),
                                    (
                                        "wish",
                                        "structure",
                                        "Expressing desires about present, past, or future",
                                        "s",
                                        "I wish I had more time. I wish I were taller.",
                                        "Use past simple for present wishes, past perfect for past wishes.",
                                        "conditionals",
                                    ),
                                ],
                            ),
                            (
                                "Advanced Passive",
                                "Complex passive constructions",
                                "grammar",
                                [
                                    (
                                        "get-passive",
                                        "structure",
                                        "A passive construction using 'get' instead of 'be'",
                                        "s",
                                        "He got promoted last month.",
                                        "Get-passive often implies a change or event.",
                                        "passive_voice",
                                    ),
                                    (
                                        "causative",
                                        "structure",
                                        "Having someone do something for you",
                                        "s",
                                        "I had my car repaired. She got her hair cut.",
                                        "Use have/get + object + past participle.",
                                        "passive_voice",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Academic Writing",
                        "Scholar-level writing",
                        [
                            (
                                "Literature Review",
                                "Surveying existing research",
                                "grammar",
                                [
                                    (
                                        "literature review",
                                        "structure",
                                        "A summary and evaluation of existing research on a topic",
                                        "s",
                                        "Recent studies suggest that bilingualism enhances cognitive function.",
                                        "Cite sources properly and synthesise findings.",
                                        "academic",
                                    ),
                                ],
                            ),
                            (
                                "Critical Essay",
                                "Analytical writing",
                                "grammar",
                                [
                                    (
                                        "critical analysis",
                                        "structure",
                                        "Evaluating strengths and weaknesses of an argument",
                                        "s",
                                        "While the author presents strong evidence, the conclusion is unsupported.",
                                        "Balance praise with critique.",
                                        "academic",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Exam Preparation",
                        "Test strategies",
                        [
                            (
                                "Proficiency Strategies",
                                "Test-taking skills",
                                "grammar",
                                [
                                    (
                                        "time management",
                                        "structure",
                                        "Allocating time wisely during exams",
                                        "s",
                                        "Spend no more than 20 minutes on each essay.",
                                        "Practice under timed conditions.",
                                        "academic",
                                    ),
                                ],
                            ),
                            (
                                "Timed Writing",
                                "Writing under pressure",
                                "grammar",
                                [
                                    (
                                        "timed essay",
                                        "structure",
                                        "A complete essay written within a set time limit",
                                        "s",
                                        "Plan for 5 minutes, write for 25, review for 5.",
                                        "Structure is even more important under time pressure.",
                                        "writing",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
            (
                "Academic",
                "academic",
                "Advanced II",
                "Academic & Professional English",
                "Master English for professional and scholarly contexts",
                [
                    (
                        "Professional English",
                        "Specialised registers",
                        [
                            (
                                "Legal English",
                                "Law-related language",
                                "grammar",
                                [
                                    (
                                        "plaintiff",
                                        "noun",
                                        "A person who brings a case against another in court",
                                        "n",
                                        "The plaintiff filed a lawsuit.",
                                        "Legal vocabulary is precise and technical.",
                                        "professional",
                                    ),
                                    (
                                        "defendant",
                                        "noun",
                                        "A person accused in a court of law",
                                        "n",
                                        "The defendant pleaded not guilty.",
                                        "Legal terms have specific meanings.",
                                        "professional",
                                    ),
                                    (
                                        "jurisdiction",
                                        "noun",
                                        "The official power to make legal decisions",
                                        "n",
                                        "The case falls under federal jurisdiction.",
                                        "Jurisdiction determines which court handles a case.",
                                        "professional",
                                    ),
                                ],
                            ),
                            (
                                "Scientific Writing",
                                "Research language",
                                "grammar",
                                [
                                    (
                                        "hypothesis",
                                        "noun",
                                        "A proposed explanation for a phenomenon, tested through experimentation",
                                        "n",
                                        "The hypothesis was supported by the data.",
                                        "Scientific writing values objectivity and precision.",
                                        "academic",
                                    ),
                                    (
                                        "methodology",
                                        "noun",
                                        "A system of methods used in a particular area of study",
                                        "n",
                                        "The methodology involved a double-blind trial.",
                                        "Describe methods in enough detail for replication.",
                                        "academic",
                                    ),
                                    (
                                        "abstract",
                                        "noun",
                                        "A brief summary of a research paper",
                                        "n",
                                        "The abstract summarises the key findings.",
                                        "Abstracts are typically 150-300 words.",
                                        "academic",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Research Communication",
                        "Scholarly discourse",
                        [
                            (
                                "Thesis Defense",
                                "Oral examination",
                                "grammar",
                                [
                                    (
                                        "thesis defense",
                                        "structure",
                                        "An oral presentation and defence of a research thesis",
                                        "s",
                                        "The candidate presented her thesis defence to the panel.",
                                        "Prepare for questions on methodology and findings.",
                                        "academic",
                                    ),
                                ],
                            ),
                            (
                                "Journal Writing",
                                "Publishing research",
                                "grammar",
                                [
                                    (
                                        "peer review",
                                        "structure",
                                        "Evaluation by experts in the same field before publication",
                                        "s",
                                        "The paper underwent rigorous peer review.",
                                        "Peer review ensures quality and validity.",
                                        "academic",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Advanced Literature",
                        "Literary mastery",
                        [
                            (
                                "Literary Analysis",
                                "Interpreting texts",
                                "grammar",
                                [
                                    (
                                        "metaphor",
                                        "noun",
                                        "A figure of speech comparing two unlike things",
                                        "n",
                                        "Time is money.",
                                        "Metaphors create vivid imagery and deeper meaning.",
                                        "literature",
                                    ),
                                    (
                                        "irony",
                                        "noun",
                                        "Expression meaning the opposite of the literal meaning",
                                        "n",
                                        "The fire station burned down.",
                                        "Irony adds layers of meaning to texts.",
                                        "literature",
                                    ),
                                ],
                            ),
                            (
                                "Creative Writing",
                                "Imaginative composition",
                                "grammar",
                                [
                                    (
                                        "narrative",
                                        "noun",
                                        "A spoken or written account of connected events",
                                        "n",
                                        "The narrative follows a young hero's journey.",
                                        "Good narratives have clear structure and vivid detail.",
                                        "literature",
                                    ),
                                    (
                                        "voice",
                                        "noun",
                                        "The distinctive style or perspective of a writer",
                                        "n",
                                        "The author's voice is warm and humorous.",
                                        "Developing a unique voice takes practice.",
                                        "literature",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
        ]

        for li, (lname, lslug, form, prof, ldesc, units_data) in enumerate(levels_data):
            level = LanguageLevel(
                language_id=lang.id,
                name=lname,
                slug=lslug,
                form_mapping=form,
                proficiency_label=prof,
                description=ldesc,
                order_index=li,
            )
            db.add(level)
            await db.flush()

            for ui, (uname, udesc, lessons_data) in enumerate(units_data):
                unit = LanguageUnit(
                    level_id=level.id,
                    name=uname,
                    description=udesc,
                    order_index=ui,
                )
                db.add(unit)
                await db.flush()

                for lesi, (les_title, les_desc, les_type, vocab_data) in enumerate(lessons_data):
                    lesson = LanguageLesson(
                        unit_id=unit.id,
                        title=les_title,
                        description=les_desc,
                        lesson_type=les_type,
                        order_index=lesi,
                    )
                    db.add(lesson)
                    await db.flush()

                    for vi, (
                        word,
                        pos,
                        trans,
                        pron,
                        ex_sent,
                        ex_trans,
                        theme,
                    ) in enumerate(vocab_data):
                        db.add(
                            LanguageVocabulary(
                                lesson_id=lesson.id,
                                word=word,
                                translation=trans,
                                pronunciation=pron,
                                part_of_speech=pos,
                                example_sentence=ex_sent,
                                example_translation=ex_trans,
                                theme=theme,
                                difficulty="beginner" if li < 2 else ("intermediate" if li < 4 else "advanced"),
                                order_index=vi,
                            )
                        )

                    grammar_entries = {
                        "Nouns & Pronouns": [
                            (
                                "Countable & Uncountable Nouns",
                                "nouns",
                                "Countable nouns can be counted (one book, two books). Uncountable nouns cannot (water, information, advice).",
                                "I have three books. I need some water.\n\nUse a/an with countable singular nouns. Use some with uncountable nouns.",
                                None,
                                "beginner",
                            ),
                        ],
                        "Verbs & Adjectives": [
                            (
                                "Action vs Linking Verbs",
                                "parts_of_speech",
                                "Action verbs show doing (run, write). Linking verbs connect the subject to a description (be, seem, feel).",
                                "She runs fast. (action)\nShe seems happy. (linking)\n\nLinking verbs are followed by adjectives, not adverbs.",
                                None,
                                "beginner",
                            ),
                        ],
                        "Articles & Prepositions": [
                            (
                                "A vs An",
                                "parts_of_speech",
                                "Use 'a' before consonant sounds and 'an' before vowel sounds.",
                                "a cat, an apple, a university (yoo sound), an hour (silent h)",
                                "Remember: it is the SOUND, not the letter, that determines a vs an.",
                                "beginner",
                            ),
                        ],
                        "Simple Sentences": [
                            (
                                "Subject-Verb-Object Order",
                                "sentence_structure",
                                "English typically follows SVO word order.",
                                "The cat (S) chased (V) the mouse (O).\nI (S) read (V) a book (O).",
                                "Questions invert subject and auxiliary: Did you read the book?",
                                "beginner",
                            ),
                        ],
                        "Questions & Negation": [
                            (
                                "Auxiliary Verbs in Questions",
                                "sentence_structure",
                                "Questions are formed by moving the auxiliary verb before the subject.",
                                "Do you like coffee? Can she swim? Have they finished?\n\nStatements: You like coffee. She can swim. They have finished.",
                                None,
                                "beginner",
                            ),
                        ],
                        "Greetings": [
                            (
                                "Formal vs Informal Register",
                                "sentence_structure",
                                "Formal English uses complete sentences and polite expressions. Informal English uses contractions and casual language.",
                                "Formal: How do you do? / Good morning.\nInformal: Hey! What's up?",
                                "Register affects word choice, grammar, and tone.",
                                "beginner",
                            ),
                        ],
                        "Numbers & Time": [
                            (
                                "Cardinal vs Ordinal Numbers",
                                "parts_of_speech",
                                "Cardinals count (one, two, three). Ordinals show position (first, second, third).",
                                "I have five books. This is my third year.",
                                "Ordinals are used for dates, floors, and rankings.",
                                "beginner",
                            ),
                        ],
                        "Family & People": [
                            (
                                "Possessive Pronouns",
                                "parts_of_speech",
                                "Show ownership: my, your, his, her, its, our, their (adjectives) vs mine, yours, his, hers, its, ours, theirs (pronouns).",
                                "This is my book. This book is mine.",
                                "Possessive pronouns replace the noun; possessive adjectives come before it.",
                                "beginner",
                            ),
                        ],
                        "Present Simple & Continuous": [
                            (
                                "Stative vs Dynamic Verbs",
                                "verb_tenses",
                                "Dynamic verbs describe actions (run, eat). Stative verbs describe states (know, believe, love). Stative verbs are rarely used in continuous form.",
                                "I am running. (correct)\nI am knowing the answer. (incorrect)\n\nI know the answer. (correct)",
                                "Common stative verbs: know, believe, want, need, love, hate, prefer.",
                                "intermediate",
                            ),
                        ],
                        "Past Simple": [
                            (
                                "Regular vs Irregular Past Tense",
                                "verb_tenses",
                                "Regular verbs add -ed (walked, played). Irregular verbs change form unpredictably.",
                                "Regular: walk/walked, play/played\nIrregular: go/went, eat/ate, see/saw\n\nThere are about 200 common irregular verbs.",
                                "Irregular verb forms must be memorised.",
                                "intermediate",
                            ),
                        ],
                        "Future Forms": [
                            (
                                "Will vs Going To",
                                "verb_tenses",
                                "Will is for predictions and spontaneous decisions. Going to is for plans and intentions.",
                                "I will help you. (spontaneous)\nI am going to visit Paris next month. (planned)",
                                "Will is also used for promises, threats, and offers.",
                                "intermediate",
                            ),
                        ],
                        "Compound Sentences": [
                            (
                                "Coordinating Conjunctions (FANBOYS)",
                                "sentence_structure",
                                "For, And, Nor, But, Or, Yet, So connect equal ideas.",
                                "I wanted to go, but it was raining.\nShe studied hard, so she passed.\n\nAlways use a comma before the conjunction.",
                                "FANBOYS is a helpful mnemonic.",
                                "intermediate",
                            ),
                        ],
                        "Complex Sentences": [
                            (
                                "Dependent vs Independent Clauses",
                                "sentence_structure",
                                "An independent clause can stand alone. A dependent clause cannot.",
                                "Independent: She went to the store.\nDependent: Although she was tired.\nCombined: Although she was tired, she went to the store.",
                                "Dependent clauses begin with subordinating conjunctions: although, because, when, if, since.",
                                "intermediate",
                            ),
                        ],
                        "Describing Things": [
                            (
                                "Irregular Comparatives & Superlatives",
                                "adjectives",
                                "Some adjectives have irregular comparative and superlative forms.",
                                "good/better/best, bad/worse/worst, far/farther/farthest, little/less/least",
                                "These forms must be memorised.",
                                "intermediate",
                            ),
                        ],
                        "Making Requests": [
                            (
                                "Politeness Strategies",
                                "professional",
                                "Using modal verbs, indirect questions, and hedging language makes requests more polite.",
                                "Can you pass the salt? (informal)\nCould you possibly pass the salt? (formal)\nI was wondering if you could pass the salt. (very formal)",
                                "The more indirect the request, the more polite it is.",
                                "intermediate",
                            ),
                        ],
                    }

                    for gi, (
                        rname,
                        rcat,
                        rexp,
                        rexamples,
                        rcontrast,
                        rdiff,
                    ) in enumerate(grammar_entries.get(les_title, [])):
                        db.add(
                            LanguageGrammarRule(
                                lesson_id=lesson.id,
                                rule_name=rname,
                                rule_category=rcat,
                                explanation=rexp,
                                examples=rexamples,
                                contrast=rcontrast,
                                difficulty=rdiff,
                                order_index=gi,
                            )
                        )

        await db.commit()
