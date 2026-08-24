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


async def seed_arabic():
    async with async_session() as db:
        existing = await db.execute(select(Language).where(Language.slug == "arabic"))
        if existing.scalar_one_or_none():
            return

        lang = Language(
            name="Arabic",
            slug="arabic",
            native_name="\u0627\u0644\u0639\u0631\u0628\u064a\u0629 (al-ʿArabiyyah)",
            icon="\U0001f54c",
            color="#059669",
            level_system="Madinah-inspired progression",
            description="Structured Arabic learning from alphabet mastery to academic proficiency",
        )
        db.add(lang)
        await db.flush()

        def mk_v(
            lid,
            word,
            pos,
            trans,
            pron,
            ex_sent,
            ex_trans,
            theme,
            diff="beginner",
            idx=0,
        ):
            return LanguageVocabulary(
                lesson_id=lid,
                word=word,
                translation=trans,
                pronunciation=pron,
                part_of_speech=pos,
                example_sentence=ex_sent,
                example_translation=ex_trans,
                theme=theme,
                difficulty=diff,
                order_index=idx,
            )

        def mk_g(lid, name, cat, expl, examples, contrast="", diff="beginner", idx=0):
            return LanguageGrammarRule(
                lesson_id=lid,
                rule_name=name,
                rule_category=cat,
                explanation=expl,
                examples=examples,
                contrast=contrast,
                difficulty=diff,
                order_index=idx,
            )

        levels_data = [
            (
                "Foundation",
                "foundation",
                "Form 1",
                "Arabic Foundation / Madinah Book 1",
                "Learn the Arabic alphabet and basics",
                [
                    (
                        "Arabic Alphabet",
                        "Letters and forms",
                        [
                            (
                                "Letters Alif to Ha",
                                "First group of letters",
                                [
                                    (
                                        "\u0627",
                                        "n",
                                        "alif (long a)",
                                        "\u0627\u0644\u0626\u0644\u0641",
                                        "\u0623\u0646\u0627 (an\u0601) - I",
                                        "The first letter of the Arabic alphabet.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u0628",
                                        "n",
                                        "ba (b)",
                                        "\u0628\u0627\u0621",
                                        "\u0628\u064a\u062a (bayt) - house",
                                        "A basic consonant with fatha, kasra, damma.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u062a",
                                        "n",
                                        "ta (t)",
                                        "\u062a\u0627\u0621",
                                        "\u062a\u0644\u0645\u064a\u0630 (talmeeذ) - student",
                                        "Two dots above the line.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u062b",
                                        "n",
                                        "tha (th)",
                                        "\u062b\u0627\u0621",
                                        "\u062b\u0644\u0627\u062b (thalaatha) - three",
                                        "Three dots above.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u062c",
                                        "n",
                                        "jim (j)",
                                        "\u062c\u064a\u0645",
                                        "\u062c\u0645\u064a\u0644 (jameel) - beautiful",
                                        "A common letter in many words.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u062d",
                                        "n",
                                        "ha (h)",
                                        "\u062d\u0627\u0621",
                                        "\u0643\u062a\u0627\u0628 (kitaab) - book",
                                        "A light, breathy h sound.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u062e",
                                        "n",
                                        "kha (kh)",
                                        "\u062e\u0627\u0621",
                                        "\u062e\u0631\u064a\u0636 (khareeذah) - garden",
                                        "A guttural sound from the throat.",
                                        "alphabet",
                                    ),
                                ],
                                [
                                    mk_g(
                                        None,
                                        "Letter Forms",
                                        "alphabet",
                                        "Arabic letters change shape depending on position: isolated, initial, medial, final.",
                                        "Book (kitaab): initial \u0643, medial \u064a, final \u0628\nEach position changes the letter's connection.",
                                        "Connected vs non-connected letters.",
                                        "beginner",
                                    ),
                                ],
                            ),
                            (
                                "Letters Dal to Ya",
                                "Second group of letters",
                                [
                                    (
                                        "\u062f",
                                        "n",
                                        "dal (d)",
                                        "\u062f\u0627\u0621",
                                        "\u062f\u0631\u0633 (dars) - lesson",
                                        "A non-connected letter.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u0630",
                                        "n",
                                        "dhal (dh)",
                                        "\u0630\u0627\u0621",
                                        "\u0630\u0647\u0628 (dhehab) - gold",
                                        "Voiced version of th.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u0631",
                                        "n",
                                        "ra (r)",
                                        "\u0631\u0627\u0621",
                                        "\u0631\u062c\u0644 (rajul) - man",
                                        "Rolled r sound.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u0632",
                                        "n",
                                        "zay (z)",
                                        "\u0632\u0627\u0621",
                                        "\u0632\u064a\u062a\u0648\u0646 (zaytun) - olive",
                                        "Like the English z.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u0639",
                                        "n",
                                        "ayn (\u02b9)",
                                        "\u0639\u064a\u0646",
                                        "\u0639\u064a\u0646 (\u02b9ayn) - eye",
                                        "A deep throat sound unique to Arabic.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u063a",
                                        "n",
                                        "ghayn (gh)",
                                        "\u063a\u064a\u0646",
                                        "\u063a\u0630\u0627\u0621 (ghidhaa\u02b9) - food",
                                        "Like French r.",
                                        "alphabet",
                                    ),
                                    (
                                        "\u0641",
                                        "n",
                                        "fa (f)",
                                        "\u0641\u0627\u0621",
                                        "\u0643\u062a\u0627\u0628 (kitaab) - book",
                                        "One dot above.",
                                        "alphabet",
                                    ),
                                ],
                                [],
                            ),
                        ],
                    ),
                    (
                        "Short Vowels",
                        "Fatha, Kasra, Damma",
                        [
                            (
                                "Fatha, Kasra, Damma",
                                "The three short vowels",
                                [
                                    (
                                        "\u064b",
                                        "n",
                                        "fatha (a)",
                                        "\u0641\u062a\u062d\u0629",
                                        "\u0643\u062a\u0628 (kataba) - he wrote",
                                        "A diagonal line above the letter.",
                                        "vowels",
                                    ),
                                    (
                                        "\u064c",
                                        "n",
                                        "damma (u)",
                                        "\u062f\u0645\u0629",
                                        "\u0643\u062a\u0628\u0648\u0627 (kataboo) - they wrote",
                                        "A small waw above the letter.",
                                        "vowels",
                                    ),
                                    (
                                        "\u064d",
                                        "n",
                                        "kasra (i)",
                                        "\u0643\u0633\u0631\u0629",
                                        "\u0643\u062a\u0628\u064a (kataba) - I wrote",
                                        "A diagonal line below the letter.",
                                        "vowels",
                                    ),
                                ],
                                [
                                    mk_g(
                                        None,
                                        "Short Vowels in Arabic",
                                        "vowels",
                                        "Arabic short vowels are written as diacritical marks above or below consonants.",
                                        "Fatha (\u064b) = a: kataba (he wrote)\nDamma (\u064c) = u: katabu (they wrote)\nKasra (\u064d) = i: katabtu (I wrote)",
                                        "In modern Arabic text, short vowels are often omitted.",
                                        "beginner",
                                    ),
                                ],
                            ),
                            (
                                "Sukun and Tanween",
                                "Unvowelled and nunation",
                                [
                                    (
                                        "\u0652",
                                        "n",
                                        "sukun (no vowel)",
                                        "\u0633\u0643\u0648\u0646",
                                        "\u0645\u0643\u062a\u0628 (maktab) - office",
                                        "A circle above the letter indicating no vowel.",
                                        "vowels",
                                    ),
                                    (
                                        "\u064b",
                                        "n",
                                        "tanween fatha",
                                        "\u062a\u0646\u0648\u064a\u0646",
                                        "\u0643\u062a\u0627\u0628\u064b (kitaaban) - a book",
                                        "Indicates indefinite accusative.",
                                        "vowels",
                                    ),
                                ],
                                [],
                            ),
                        ],
                    ),
                ],
            ),
            (
                "Beginner",
                "beginner",
                "Form 2",
                "Beginner / Madinah Book 2",
                "Build core vocabulary and grammar",
                [
                    (
                        "Noun Patterns",
                        "Plurals and duals",
                        [
                            (
                                "Broken Plurals",
                                "Irregular plurals",
                                [
                                    (
                                        "\u0643\u064a\u062a\u0627\u0628",
                                        "n",
                                        "book (singular)",
                                        "kitaab",
                                        "\u0643\u064a\u062a\u0627\u0628 (kitaab) - book",
                                        "One book.",
                                        "nouns",
                                    ),
                                    (
                                        "\u0643\u064a\u062a\u0628",
                                        "n",
                                        "books (plural)",
                                        "kutub",
                                        "\u0643\u062a\u0628 \u0643\u062b\u064a\u0631\u0629 (kutub katheera) - many books",
                                        "Broken plural pattern fu\u02b9l.",
                                        "nouns",
                                    ),
                                    (
                                        "\u0645\u0636\u0631\u0639",
                                        "n",
                                        "mosque",
                                        "masjid",
                                        "\u0627\u0644\u0645\u0636\u0631\u0639 (al-masjid) - the mosque",
                                        "Singular form.",
                                        "nouns",
                                    ),
                                    (
                                        "\u0645\u0636\u0627\u0631\u0639",
                                        "n",
                                        "mosques",
                                        "masaajid",
                                        "\u0645\u0636\u0627\u062c\u0639 \u0643\u062b\u064a\u0631\u0629 (masaajid katheera)",
                                        "Broken plural pattern mafaaji\u02b9l.",
                                        "nouns",
                                    ),
                                ],
                                [
                                    mk_g(
                                        None,
                                        "Broken Plurals",
                                        "nouns",
                                        "Arabic broken plurals change the internal vowel pattern of the singular noun.",
                                        "Pattern fu\u02b9l: kitaab \u2192 kutub (books)\nPattern mafaaji\u02b9l: masjid \u2192 masaajid (mosques)\nThere are many patterns to memorise.",
                                        "Unlike English, Arabic plurals change the word structure.",
                                        "intermediate",
                                    ),
                                ],
                            ),
                            (
                                "Dual Form",
                                "Two of something",
                                [
                                    (
                                        "\u0643\u064a\u062a\u0627\u0628\u0627\u0646",
                                        "n",
                                        "two books",
                                        "kitaabaa\u02b9",
                                        "\u0639\u0646\u062f\u064a \u0643\u064a\u062a\u0627\u0628\u0627\u0646 (indi kitaabaa\u02b9) - I have two books",
                                        "Dual adds \u0627\u0646 to the end.",
                                        "nouns",
                                    ),
                                ],
                                [],
                            ),
                        ],
                    ),
                    (
                        "Pronouns & Sentences",
                        "Building blocks",
                        [
                            (
                                "Personal Pronouns",
                                "Subject pronouns",
                                [
                                    (
                                        "\u0623\u0646\u0627",
                                        "pronoun",
                                        "I",
                                        "an\u0601",
                                        "\u0623\u0646\u0627 \u0637\u0627\u0644\u0628 (an\u0601 ṭaalib) - I am a student",
                                        "First person singular.",
                                        "pronouns",
                                    ),
                                    (
                                        "\u0647\u0648\u0627",
                                        "pronoun",
                                        "he",
                                        "huwa",
                                        "\u0647\u0648\u0627 \u0645\u064f\u062f\u0631\u0633 (huwa mudarris) - He is a teacher",
                                        "Third person masculine.",
                                        "pronouns",
                                    ),
                                    (
                                        "\u0647\u064a",
                                        "pronoun",
                                        "she",
                                        "hiya",
                                        "\u0647\u064a \u0637\u0627\u0644\u0628\u0629 (hiya ṭaaliba) - She is a student",
                                        "Third person feminine.",
                                        "pronouns",
                                    ),
                                    (
                                        "\u0646\u062d\u0646\u064f",
                                        "pronoun",
                                        "we",
                                        "naḥnu",
                                        "\u0646\u062d\u0646\u064f \u0645\u0633\u0644\u0645\u0648\u0646 (naḥnu muslimoon) - We are Muslims",
                                        "First person plural.",
                                        "pronouns",
                                    ),
                                ],
                                [
                                    mk_g(
                                        None,
                                        "Nominal Sentence \u0627\u0644\u062c\u0645\u0644\u0629 \u0627\u0644\u0627\u0633\u0645\u064a\u0629",
                                        "sentence_types",
                                        "A nominal sentence begins with a noun/pronoun (subject) and a predicate.",
                                        "An\u0601 ṭaalib - I am a student\nHuwa mudarris - He is a teacher\nNo verb 'to be' is needed in present tense.",
                                        "Arabic has no present tense copula.",
                                        "beginner",
                                    ),
                                ],
                            ),
                            (
                                "Verbal Sentences",
                                "VSO order",
                                [],
                                [
                                    mk_g(
                                        None,
                                        "Verbal Sentence \u0627\u0644\u062c\u0645\u0644\u0629 \u0627\u0644\u0641\u0639\u0644\u064a\u0629",
                                        "sentence_types",
                                        "A verbal sentence begins with the verb, followed by the subject and object.",
                                        "Kataba al-waladu al-darsa - The boy wrote the lesson\nVerb-Subject-Object (VSO) order is default.",
                                        "VSO is the default word order in Classical and Modern Standard Arabic.",
                                        "beginner",
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
                "Intermediate / Madinah Book 3",
                "Master verb forms and case system",
                [
                    (
                        "Verb System",
                        "Past, present, imperative",
                        [
                            (
                                "Past Tense (\u0627\u0644\u0645\u0627\u0636\u064a)",
                                "Completed actions",
                                [
                                    (
                                        "\u0643\u062a\u0628\u064e",
                                        "verb",
                                        "he wrote",
                                        "kataba",
                                        "\u0643\u062a\u0628\u064e \u0627\u0644\u0648\u0644\u062f\u064f \u0627\u0644\u062f\u0631\u0633\u064e - The boy wrote the lesson",
                                        "Past tense is formed by adding prefixes/suffixes.",
                                        "verbs_past",
                                    ),
                                    (
                                        "\u0643\u062a\u0628\u062a\u064f",
                                        "verb",
                                        "I wrote",
                                        "katabtu",
                                        "\u0643\u062a\u0628\u062a\u064f \u0631\u0633\u0627\u0644\u0629 - I wrote a letter",
                                        "Subject pronouns are suffixes in past tense.",
                                        "verbs_past",
                                    ),
                                ],
                                [
                                    mk_g(
                                        None,
                                        "Past Tense Formation",
                                        "verbs_past",
                                        "Add subject suffixes to the past tense verb stem.",
                                        "kataba (he wrote)\nkatabtu (I wrote)\nkatabna (we wrote)\nkatabtum (you pl. wrote)",
                                        "Subject is indicated by suffixes, not separate pronouns.",
                                        "intermediate",
                                    ),
                                ],
                            ),
                            (
                                "Present Tense (\u0627\u0644\u0645\u0636\u0627\u0631\u0639)",
                                "Ongoing actions",
                                [
                                    (
                                        "\u064a\u0643\u062a\u0628\u064f",
                                        "verb",
                                        "he writes",
                                        "yaktubu",
                                        "\u064a\u0643\u062a\u0628\u064f \u0627\u0644\u0637\u0627\u0644\u0628\u064f - The student writes",
                                        "Present tense has different patterns.",
                                        "verbs_present",
                                    ),
                                ],
                                [],
                            ),
                        ],
                    ),
                    (
                        "Case System",
                        "The heart of Arabic grammar",
                        [
                            (
                                "Raf\u02bb (\u0631\u0641\u0639)",
                                "Nominative case",
                                [
                                    (
                                        "\u0627\u0644\u0648\u0644\u062f\u064f",
                                        "n",
                                        "the boy (nominative)",
                                        "al-waladu",
                                        "\u062c\u0627\u0621\u064e \u0627\u0644\u0648\u0644\u062f\u064f - The boy came",
                                        "Subject takes raf\u02bb (damma ending).",
                                        "case_system",
                                    ),
                                ],
                                [
                                    mk_g(
                                        None,
                                        "Case Endings (\u0627\u0644\u0625\u0639\u0631\u0627\u0628)",
                                        "case_system",
                                        "Arabic nouns change their ending based on their grammatical role.",
                                        "Raf\u02bb (nominative): al-waladu (the boy - subject)\nNaṣb (accusative): al-walada (the boy - object)\nJar\u02bb (genitive): waladi (of the boy - possessive)",
                                        "Case endings are essential for understanding Arabic sentences.",
                                        "intermediate",
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
                "Master complex grammar",
                [
                    (
                        "Derived Verb Forms",
                        "The ten verb forms",
                        [
                            (
                                "Forms I-V",
                                "Basic derivations",
                                [
                                    (
                                        "\u0643\u062a\u0628\u064e",
                                        "verb",
                                        "Form I - he wrote",
                                        "kataba",
                                        "\u0643\u062a\u0628\u064e - basic form: to write",
                                        "Form I is the base pattern.",
                                        "derived_verbs",
                                    ),
                                    (
                                        "\u0643\u062a\u0628\u064e",
                                        "verb",
                                        "Form II - he dictated",
                                        "kattaba",
                                        "\u0643\u0627\u062a\u0628\u064e - to dictate (Form II)",
                                        "Form II doubles the middle radical: causative/intensive.",
                                        "derived_verbs",
                                    ),
                                    (
                                        "\u0623\u0643\u062a\u0628\u064e",
                                        "verb",
                                        "Form III - he corresponded",
                                        "aaktaba",
                                        "\u0623\u0643\u062a\u0628\u064e - to correspond (Form III)",
                                        "Form III adds alif after first radical: reciprocal.",
                                        "derived_verbs",
                                    ),
                                    (
                                        "\u0623\u0643\u062a\u0628\u064e",
                                        "verb",
                                        "Form IV - he caused to write",
                                        "aktaba",
                                        "\u0623\u0643\u062a\u0628\u064e - to cause to write",
                                        "Form IV: causative.",
                                        "derived_verbs",
                                    ),
                                    (
                                        "\u062a\u0643\u0627\u062a\u0628\u064e",
                                        "verb",
                                        "Form V - he studied",
                                        "takattaba",
                                        "\u062a\u0643\u0627\u062a\u0628\u064e - to study (Form V)",
                                        "Form V: reflexive of Form II.",
                                        "derived_verbs",
                                    ),
                                ],
                                [
                                    mk_g(
                                        None,
                                        "Arabic Verb Forms I-X",
                                        "derived_verbs",
                                        "Arabic has ten standard verb forms derived from trilateral roots.",
                                        "Form I: kataba (to write)\nForm II: kattaba (to dictate)\nForm III: aaktaba (to correspond)\nForm IV: aktaba (to cause to write)\nForm V: takattaba (to be written/correspond)",
                                        "Each form adds specific meaning to the root k-t-b.",
                                        "intermediate",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Connected Reading",
                        "Real texts",
                        [
                            (
                                "Reading Skills",
                                "Text comprehension",
                                [],
                                [
                                    mk_g(
                                        None,
                                        "Reading Arabic Texts",
                                        "sentence_types",
                                        "Arabic texts use connected script with optional vowel markings.",
                                        "Reading without tashkeel (vowels) requires context knowledge\nPractice: Read the news, short stories, and Quranic passages",
                                        "Reading skill improves dramatically with practice.",
                                        "intermediate",
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
                "Advanced Arabic",
                "Literary and formal Arabic",
                [
                    (
                        "Advanced Grammar",
                        "Expert-level structures",
                        [
                            (
                                "Advanced \u0627\u0644\u0625\u0639\u0631\u0627\u0628",
                                "Case system mastery",
                                [],
                                [
                                    mk_g(
                                        None,
                                        "Advanced Case Endings",
                                        "case_system",
                                        "Mastering all case rules including tamyeez, \u1e25aal, and istithnaa\u02b9.",
                                        "Tamyeez: distinguishing specification\n\u1e24aal: circumstantial accusative\nIstithnaa\u02b9: exception constructions",
                                        "These structures appear in formal and literary Arabic.",
                                        "advanced",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Literary Arabic",
                        "Classical beauty",
                        [
                            (
                                "Rhetoric (\u0627\u0644\u0628\u0644\u0627\u063a\u0629)",
                                "The science of eloquence",
                                [],
                                [
                                    mk_g(
                                        None,
                                        "Arabic Rhetoric (Bal\u0101ghah)",
                                        "literary",
                                        "Arabic rhetoric encompasses metaphor (isti\u02b9aara), metonymy (maj\u00e1z), and other figures of speech.",
                                        "Metaphor: al-wajhu qamarun - The face is a moon\nMetonymy:Reading the Book means studying the Quran",
                                        "Bal\u0101ghah is considered the highest science in Arabic tradition.",
                                        "advanced",
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
                "Academic & Professional Arabic",
                "Master Arabic for professional contexts",
                [
                    (
                        "Professional Arabic",
                        "Specialised registers",
                        [
                            (
                                "Business Arabic",
                                "Commercial language",
                                [],
                                [
                                    mk_g(
                                        None,
                                        "Business Arabic Vocabulary",
                                        "professional",
                                        "Business Arabic uses formal vocabulary and specific terminology.",
                                        "Contract: \u0639\u0642\u062f (aqd)\nClause: \u0634\u0631\u0637 (sharT)\nPartnership: \u0634\u0631\u0643\u0629 (sharika)",
                                        "Register must match the formality of the context.",
                                        "advanced",
                                    ),
                                ],
                            ),
                        ],
                    ),
                    (
                        "Research & Translation",
                        "Academic tools",
                        [
                            (
                                "Translation",
                                "Cross-cultural communication",
                                [],
                                [
                                    mk_g(
                                        None,
                                        "Translation Principles",
                                        "literary",
                                        "Translation between Arabic and other languages requires cultural awareness.",
                                        "Literal translation vs. dynamic equivalence\nArabic-English: consider idiom, register, and cultural context",
                                        "Good translation is an art as well as a science.",
                                        "advanced",
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

                for lesi, item in enumerate(lessons_data):
                    les_title, les_desc = item[0], item[1]
                    vocab_data = item[2]
                    grammar_data = item[3] if len(item) > 3 else []

                    lesson = LanguageLesson(
                        unit_id=unit.id,
                        title=les_title,
                        description=les_desc,
                        lesson_type="grammar",
                        order_index=lesi,
                    )
                    db.add(lesson)
                    await db.flush()

                    for vi, vtuple in enumerate(vocab_data):
                        diff = "beginner" if li < 2 else ("intermediate" if li < 4 else "advanced")
                        db.add(
                            mk_v(
                                lesson.id,
                                vtuple[0],
                                vtuple[1],
                                vtuple[2],
                                vtuple[3],
                                vtuple[4],
                                vtuple[5],
                                vtuple[6],
                                diff,
                                vi,
                            )
                        )

                    for gi, g in enumerate(grammar_data):
                        if hasattr(g, "lesson_id"):
                            g.lesson_id = lesson.id
                            g.order_index = gi
                            db.add(g)

        await db.commit()
