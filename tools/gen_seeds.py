#!/usr/bin/env python3
"""Generate Chinese and Arabic seed files."""
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANG_DIR = os.path.join(BASE, "backend", "app", "languages")

# ─── CHINESE SEED ──────────────────────────────────────────────────────
chinese_code = r'''from sqlalchemy import select

from app.database.engine import async_session
from app.models.languages import (
    Language,
    LanguageGrammarRule,
    LanguageLesson,
    LanguageLevel,
    LanguageUnit,
    LanguageVocabulary,
)


async def seed_chinese():
    async with async_session() as db:
        existing = await db.execute(select(Language).where(Language.slug == "chinese"))
        if existing.scalar_one_or_none():
            return

        lang = Language(
            name="Chinese", slug="chinese", native_name="\u4e2d\u6587 (Zh\u014dngw\u00e9n)",
            icon="\U0001f1e8\U0001f1f3", color="#DC2626",
            level_system="HSK-inspired progression",
            description="Progressive Chinese learning from foundation to advanced proficiency, aligned with HSK standards",
        )
        db.add(lang)
        await db.flush()

        def mk_v(lid, word, pos, trans, pron, ex_sent, ex_trans, theme, diff="beginner", idx=0):
            return LanguageVocabulary(
                lesson_id=lid, word=word, translation=trans, pronunciation=pron,
                part_of_speech=pos, example_sentence=ex_sent,
                example_translation=ex_trans, theme=theme, difficulty=diff, order_index=idx,
            )

        def mk_g(lid, name, cat, expl, examples, contrast="", diff="beginner", idx=0):
            return LanguageGrammarRule(
                lesson_id=lid, rule_name=name, rule_category=cat,
                explanation=expl, examples=examples, contrast=contrast,
                difficulty=diff, order_index=idx,
            )

        levels_data = [
            ("HSK 1 Foundation", "hsk1", "Form 1", "HSK 1 / Foundation", "Begin your Chinese journey", [
                ("Characters", "Learning Chinese characters and numbers", [
                    ("Numbers 1-10", "Basic number characters", [
                        ("\u4e00", "num", "one", "y\u012b", "y\u012b g\u00e8 r\u00e9n - one person", "I have one apple.", "numbers"),
                        ("\u4e8c", "num", "two", "\u00e8r", "\u00e8r g\u00e8 xu\u00e9sh\u0113ng - two students", "We have two cats.", "numbers"),
                        ("\u4e09", "num", "three", "s\u0101n", "s\u0101n di\u01cen zh\u014dng - three o'clock", "I like March.", "numbers"),
                        ("\u56db", "num", "four", "s\u00ec", "s\u00ec g\u00e8 xu\u00e9sh\u0113ng - four students", "Four sounds like death in Chinese.", "numbers"),
                        ("\u4e94", "num", "five", "w\u01d4", "w\u01d4 di\u01cen zh\u014dng - five o'clock", "May is the fifth month.", "numbers"),
                        ("\u516d", "num", "six", "li\u00f9", "li\u00f9 g\u00e8 yu\u00e8 - June", "Six is considered lucky.", "numbers"),
                        ("\u4e03", "num", "seven", "q\u012b", "q\u012b di\u01cen zh\u014dng - seven o'clock", "Seven sounds like arise.", "numbers"),
                        ("\u516b", "num", "eight", "b\u0101", "b\u0101 di\u01cen zh\u014dng - eight o'clock", "Eight is very lucky in Chinese.", "numbers"),
                        ("\u4e5d", "num", "nine", "ji\u01d4", "ji\u01d4 g\u00e8 yu\u00e8 - September", "Nine sounds like long-lasting.", "numbers"),
                        ("\u5341", "num", "ten", "sh\u00ed", "sh\u00ed g\u00e8 xu\u00e9sh\u0113ng - ten students", "sh\u00ed f\u0113n h\u01ceo - very good", "numbers"),
                    ], [
                        mk_g(None, "Measure Words (\u91cf\u8bcd)", "measure_words",
                             "Chinese requires a measure word between a number and a noun.",
                             "y\u012b g\u00e8 r\u00e9n (one person)\ny\u012b zh\u012b m\u0101o (one cat)\ny\u012b b\u0113n sh\u016b (one book)",
                             "Different nouns use different measure words.", "beginner"),
                    ]),
                    ("Common Radicals", "Building blocks of characters", [
                        ("\u4eba", "rad", "person radical", "r\u00e9n", "t\u0101 - he, n\u01d0 - you", "Appears in many characters.", "characters"),
                        ("\u6c34", "rad", "water radical", "shu\u01d0", "h\u00e9 - river, h\u01cei - sea", "Written as three dots.", "characters"),
                        ("\u6728", "rad", "wood radical", "m\u00f9", "sh\u00f9 - tree, gu\u01d2 - fruit", "Appears in nature characters.", "characters"),
                        ("\u53e3", "rad", "mouth radical", "k\u01d2u", "ch\u012b - eat, h\u0113 - drink", "One of the most common.", "characters"),
                        ("\u5973", "rad", "woman radical", "n\u01d4", "m\u0101 - mother, ji\u0113 - sister", "Appears in female-related characters.", "characters"),
                    ], []),
                ]),
                ("Greetings", "Essential daily phrases", [
                    ("Basic Greetings", "Hello and farewell", [
                        ("\u4f60\u597d", "greeting", "hello", "n\u01d0 h\u01ceo", "N\u01d0 h\u01ceo, w\u01d2 ji\u00e0o W\u00e1ng M\u00edng", "The most common Chinese greeting.", "greetings"),
                        ("\u65e9\u4e0a\u597d", "greeting", "good morning", "z\u01ceo shang h\u01ceo", "Z\u01ceo shang h\u01ceo! N\u01d0 h\u01ceo ma?", "Used before noon.", "greetings"),
                        ("\u8c22\u8c22", "excl", "thank you", "xi\u00e8xie", "Xi\u00e8xie n\u01d0!", "Most common way to say thanks.", "greetings"),
                        ("\u518d\u89c1", "greeting", "goodbye", "z\u00e0iji\u00e0n", "M\u00edngti\u0101n ji\u00e0n! - See you tomorrow!", "Literally means see again.", "greetings"),
                        ("\u5bf9\u4e0d\u8d77", "excl", "sorry", "du\u00ecbuq\u01d0", "Du\u00ecbuq\u01d0, w\u01d2 l\u00e1i w\u01cen le", "Used to apologise.", "greetings"),
                    ], [
                        mk_g(None, "Yes/No Questions with \u5417", "questions",
                             "Add \u5417 at the end of a statement to form a question.",
                             "N\u01d0 sh\u00ec xu\u00e9sh\u0113ng ma? - Are you a student?\nN\u01d0 h\u0113 ch\u00e1 ma? - Do you drink tea?",
                             "\u5417 is the most common question particle.", "beginner"),
                        mk_g(None, "Negation with \u4e0d", "negation",
                             "Place \u4e0d before the verb to negate.",
                             "W\u01d2 b\u00f9 sh\u00ec l\u01ceosh\u012b - I am not a teacher\nW\u01d2 b\u00f9 h\u0113 k\u0101f\u0113i - I don't drink coffee",
                             "\u4e0d is the general negator.", "beginner"),
                    ]),
                    ("Self-Introduction", "Talking about yourself", [
                        ("\u540d\u5b57", "n", "name", "m\u00edngz\u00ec", "W\u01d2 ji\u00e0o L\u01d0 Hu\u00e1", "Used when introducing yourself.", "self-intro"),
                        ("\u6211", "pronoun", "I / me", "w\u01d2", "W\u01d2 sh\u00ec xu\u00e9sh\u0113ng - I am a student", "Subject and object pronoun.", "self-intro"),
                        ("\u4f60", "pronoun", "you", "n\u01d0", "N\u01d0 sh\u00ec n\u01ce l\u01d0 r\u00e9n? - Where are you from?", "Informal you.", "self-intro"),
                        ("\u662f", "verb", "to be", "sh\u00ec", "W\u01d2 sh\u00ec l\u01ceosh\u012b - I am a teacher", "Basic copula verb.", "self-intro"),
                    ], []),
                ]),
            ]),
            ("HSK 2 Elementary", "hsk2", "Form 2", "HSK 2 / Elementary", "Expand your vocabulary", [
                ("Vocabulary", "Everyday words", [
                    ("Food & Drink", "Common food vocabulary", [
                        ("\u8336", "n", "tea", "ch\u00e1", "W\u01d2 x\u012bhuan h\u0113 ch\u00e1", "Tea is central to Chinese culture.", "food"),
                        ("\u996d", "n", "rice / meal", "f\u00e0n", "N\u01d0 ch\u012b f\u00e0n le ma? - Have you eaten?", "A greeting in Chinese culture.", "food"),
                        ("\u6c34", "n", "water", "shu\u01d0", "W\u01d2 y\u00e0o y\u012b b\u0113i shu\u01d0", "Essential daily word.", "food"),
                        ("\u82f9\u679c", "n", "apple", "p\u00ednggu\u01d2", "P\u00ednggu\u01d2 h\u0113n h\u01ceo ch\u012b", "Literally means peace fruit.", "food"),
                        ("\u9762\u6761", "n", "noodles", "mi\u00e0nti\u00e1o", "W\u01d2 y\u00e0o y\u012b w\u01cen mi\u00e0nti\u00e1o", "Noodles symbolise long life.", "food"),
                        ("\u8c46\u8150", "n", "tofu", "d\u00f2ufu", "M\u00e1l\u00e0 d\u00f2ufu - spicy tofu", "A staple of Chinese cuisine.", "food"),
                    ], []),
                    ("Body & Health", "Body parts", [
                        ("\u5934", "n", "head", "t\u00f3u", "W\u01d2 de t\u00f3u h\u0113n t\u00e9ng", "Basic body part.", "body"),
                        ("\u773c\u775b", "n", "eyes", "y\u01cenj\u012bng", "Y\u01cenj\u012bng sh\u00ec l\u00edngh\u00fapn zh\u012b chu\u0101ng", "Used in many idioms.", "body"),
                        ("\u624b", "n", "hand", "sh\u01d2u", "Q\u012bng n\u01d0 j\u01d3 sh\u01d2u", "Essential body word.", "body"),
                        ("\u811a", "n", "foot / leg", "ji\u01ceo", "W\u01d2 de ji\u01ceo t\u00e9ng", "Used for both foot and leg.", "body"),
                    ], []),
                ]),
                ("Grammar", "Key patterns", [
                    ("The \u628a Sentence", "Word order", [], [
                        mk_g(None, "\u628a Construction", "sentence_order",
                             "The \u628a construction moves the object before the verb.",
                             "W\u01d2 b\u0101 sh\u016b f\u00e0ng z\u00e0i zhu\u01d2u shang - I put the book on the table",
                             "Use \u628a when the result of the action is important.", "intermediate"),
                    ]),
                ]),
            ]),
            ("HSK 3 Lower Intermediate", "hsk3", "Form 3", "HSK 3 / Lower Intermediate", "Develop intermediate skills", [
                ("Grammar Patterns", "Intermediate grammar", [
                    ("Aspect Particles", "Tense and aspect", [
                        ("\u4e86", "particle", "completed action", "le", "W\u01d2 ch\u012b le f\u00e0n - I ate", "Marks completed action.", "particles"),
                        ("\u7740", "particle", "continuous state", "zhe", "M\u00e9n k\u0101i zhe - The door is open", "Shows ongoing state.", "particles"),
                        ("\u8fc7", "particle", "past experience", "guo", "W\u01d2 q\u00fc guo Zh\u014dnggu\u00f3 - I have been to China", "Indicates past experience.", "particles"),
                    ], [
                        mk_g(None, "Aspect Particles \u4e86\u7740\u8fc7", "aspect",
                             "Chinese uses particles instead of verb conjugation.",
                             "\u4e86 - completed: W\u01d2 ch\u012b le f\u00e0n (I ate)\n\u7740 - ongoing: m\u00e9n k\u0101i zhe (door is open)\n\u8fc7 - experience: W\u01d2 q\u00fc guo (I have been)",
                             "Unlike English, Chinese verbs do not change form.", "intermediate"),
                    ]),
                    ("Comparisons", "Comparing things", [
                        ("\u6bd4", "prep", "to compare", "b\u01d0", "W\u01d2 b\u01d0 n\u01d0 g\u01ceo - I am taller than you", "Used in comparison structures.", "comparisons"),
                        ("\u6ca1\u6709", "adv", "not have", "m\u00e9iy\u01d2u", "W\u01d2 m\u00e9iy\u01d2u sh\u00edji\u0101n - I don't have time", "Negative of have.", "comparisons"),
                    ], []),
                ]),
            ]),
            ("HSK 4 Intermediate", "hsk4", "Form 4", "HSK 4 / Intermediate", "Master complex structures", [
                ("Advanced Grammar", "Complex patterns", [
                    ("Passive with \u88ab", "Passive voice", [], [
                        mk_g(None, "Passive Construction \u88ab", "passive",
                             "Use \u88ab to form passive sentences in Chinese.",
                             "T\u0101 b\u00e8i l\u01ceosh\u012b p\u00edngp\u00edng le - He was criticised by the teacher\nFangzi b\u00e8i m\u00e1o le - The house was sold",
                             "The agent follows \u88ab but can be omitted.", "intermediate"),
                    ]),
                    ("Formal Writing", "Academic Chinese", [], [
                        mk_g(None, "Written Register", "formal",
                             "Formal Chinese uses different vocabulary and structures than spoken Chinese.",
                             "Written: \u56e0\u6b64 (therefore), \u7136\u540e (afterwards)\nSpoken: \u6240\u4ee5, \u540e\u6765",
                             "Written Chinese often uses classical vocabulary.", "advanced"),
                    ]),
                ]),
            ]),
            ("HSK 5 Advanced", "hsk5", "Advanced I", "HSK 5 / Advanced", "Achieve advanced fluency", [
                ("Literary Chinese", "Classical elements", [
                    ("Chengyu (\u6210\u8bed)", "Four-character idioms", [], [
                        mk_g(None, "Chinese Idioms (\u6210\u8bed)", "formal",
                             "Chengyu are four-character expressions from history, literature, or fables.",
                             "\u753b\u86c7\u6dfb\u8db3 (hu\u00e0 sh\u0113 ti\u0101n z\u00fa) - draw a snake and add feet (ruin by adding)\n\u5b8c\u74e6\u5168\u7389 (w\u00e1n w\u00e1 qu\u00e1n y\u00f9) - a perfect jade (flawless)",
                             "Chengyu are essential for advanced Chinese.", "advanced"),
                    ]),
                ]),
                ("Professional Chinese", "Business and media", [
                    ("Business Register", "Formal vocabulary", [], [
                        mk_g(None, "Business Chinese Register", "formal",
                             "Business Chinese uses formal vocabulary and polite expressions.",
                             "Draft: \u62df\u8bae (propose), \u5c0a\u656c\u7684 (esteemed)\nContract: \u5408\u540c (contract), \u6761\u6b3e (clause)",
                             "Register shifts between formal and casual.", "advanced"),
                    ]),
                ]),
            ]),
            ("HSK 6 Proficiency", "hsk6", "Advanced II", "HSK 6 / Proficiency", "Master Chinese at the highest level", [
                ("Mastery", "Expert-level Chinese", [
                    ("Rhetorical Devices", "Advanced expression", [], [
                        mk_g(None, "Rhetoric in Chinese", "formal",
                             "Chinese uses parallel structures, antithesis, and allusions for emphasis.",
                             "\u5c71\u91cd\u6c34\u590d\u7591\u6742\u8def\u7591 (sh\u0101n zh\u00f2ng shu\u01d0 f\u00f9, l\u00f9 zh\u00ed y\u01d2uq\u016b) - mountains multiply, streams double back\nThis is a famous line by Lu You.",
                             "Classical allusions enrich modern Chinese.", "advanced"),
                    ]),
                ]),
                ("Specialized Domains", "Professional Chinese", [
                    ("Translation", "Cross-cultural communication", [], [
                        mk_g(None, "Translation Principles", "formal",
                             "Translation between Chinese and other languages requires attention to register, idiom, and cultural context.",
                             "Literal: \u76f4\u8bd1 (zh\u00ed y\u00ec)\nFree: \u610f\u8bd1 (y\u00ec y\u00ec)\nAdaptation: \u521b\u610f\u8bd1 (chu\u00e0ng y\u00ec y\u00ec)",
                             "Good translation balances accuracy and naturalness.", "advanced"),
                    ]),
                ]),
            ]),
        ]

        for li, (lname, lslug, form, prof, ldesc, units_data) in enumerate(levels_data):
            level = LanguageLevel(
                language_id=lang.id, name=lname, slug=lslug,
                form_mapping=form, proficiency_label=prof, description=ldesc,
                order_index=li,
            )
            db.add(level)
            await db.flush()

            for ui, (uname, udesc, lessons_data) in enumerate(units_data):
                unit = LanguageUnit(
                    level_id=level.id, name=uname, description=udesc, order_index=ui,
                )
                db.add(unit)
                await db.flush()

                for lesi, item in enumerate(lessons_data):
                    les_title, les_desc = item[0], item[1]
                    vocab_data = item[2]
                    grammar_data = item[3] if len(item) > 3 else []

                    lesson = LanguageLesson(
                        unit_id=unit.id, title=les_title, description=les_desc,
                        lesson_type="grammar", order_index=lesi,
                    )
                    db.add(lesson)
                    await db.flush()

                    for vi, vtuple in enumerate(vocab_data):
                        diff = "beginner" if li < 2 else ("intermediate" if li < 4 else "advanced")
                        db.add(mk_v(lesson.id, vtuple[0], vtuple[1], vtuple[2],
                                    vtuple[3], vtuple[4], vtuple[5], vtuple[6], diff, vi))

                    for gi, g in enumerate(grammar_data):
                        if hasattr(g, 'lesson_id'):
                            g.lesson_id = lesson.id
                            g.order_index = gi
                            db.add(g)

        await db.commit()
'''

# ─── ARABIC SEED ───────────────────────────────────────────────────────
arabic_code = r'''from sqlalchemy import select

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
            name="Arabic", slug="arabic", native_name="\u0627\u0644\u0639\u0631\u0628\u064a\u0629 (al-ʿArabiyyah)",
            icon="\U0001f54c", color="#059669",
            level_system="Madinah-inspired progression",
            description="Structured Arabic learning from alphabet mastery to academic proficiency",
        )
        db.add(lang)
        await db.flush()

        def mk_v(lid, word, pos, trans, pron, ex_sent, ex_trans, theme, diff="beginner", idx=0):
            return LanguageVocabulary(
                lesson_id=lid, word=word, translation=trans, pronunciation=pron,
                part_of_speech=pos, example_sentence=ex_sent,
                example_translation=ex_trans, theme=theme, difficulty=diff, order_index=idx,
            )

        def mk_g(lid, name, cat, expl, examples, contrast="", diff="beginner", idx=0):
            return LanguageGrammarRule(
                lesson_id=lid, rule_name=name, rule_category=cat,
                explanation=expl, examples=examples, contrast=contrast,
                difficulty=diff, order_index=idx,
            )

        levels_data = [
            ("Foundation", "foundation", "Form 1", "Arabic Foundation / Madinah Book 1", "Learn the Arabic alphabet and basics", [
                ("Arabic Alphabet", "Letters and forms", [
                    ("Letters Alif to Ha", "First group of letters", [
                        ("\u0627", "n", "alif (long a)", "\u0627\u0644\u0626\u0644\u0641", "\u0623\u0646\u0627 (an\u0601) - I", "The first letter of the Arabic alphabet.", "alphabet"),
                        ("\u0628", "n", "ba (b)", "\u0628\u0627\u0621", "\u0628\u064a\u062a (bayt) - house", "A basic consonant with fatha, kasra, damma.", "alphabet"),
                        ("\u062a", "n", "ta (t)", "\u062a\u0627\u0621", "\u062a\u0644\u0645\u064a\u0630 (talmeeذ) - student", "Two dots above the line.", "alphabet"),
                        ("\u062b", "n", "tha (th)", "\u062b\u0627\u0621", "\u062b\u0644\u0627\u062b (thalaatha) - three", "Three dots above.", "alphabet"),
                        ("\u062c", "n", "jim (j)", "\u062c\u064a\u0645", "\u062c\u0645\u064a\u0644 (jameel) - beautiful", "A common letter in many words.", "alphabet"),
                        ("\u062d", "n", "ha (h)", "\u062d\u0627\u0621", "\u0643\u062a\u0627\u0628 (kitaab) - book", "A light, breathy h sound.", "alphabet"),
                        ("\u062e", "n", "kha (kh)", "\u062e\u0627\u0621", "\u062e\u0631\u064a\u0636 (khareeذah) - garden", "A guttural sound from the throat.", "alphabet"),
                    ], [
                        mk_g(None, "Letter Forms", "alphabet",
                             "Arabic letters change shape depending on position: isolated, initial, medial, final.",
                             "Book (kitaab): initial \u0643, medial \u064a, final \u0628\nEach position changes the letter's connection.",
                             "Connected vs non-connected letters.", "beginner"),
                    ]),
                    ("Letters Dal to Ya", "Second group of letters", [
                        ("\u062f", "n", "dal (d)", "\u062f\u0627\u0621", "\u062f\u0631\u0633 (dars) - lesson", "A non-connected letter.", "alphabet"),
                        ("\u0630", "n", "dhal (dh)", "\u0630\u0627\u0621", "\u0630\u0647\u0628 (dhehab) - gold", "Voiced version of th.", "alphabet"),
                        ("\u0631", "n", "ra (r)", "\u0631\u0627\u0621", "\u0631\u062c\u0644 (rajul) - man", "Rolled r sound.", "alphabet"),
                        ("\u0632", "n", "zay (z)", "\u0632\u0627\u0621", "\u0632\u064a\u062a\u0648\u0646 (zaytun) - olive", "Like the English z.", "alphabet"),
                        ("\u0639", "n", "ayn (\u02b9)", "\u0639\u064a\u0646", "\u0639\u064a\u0646 (\u02b9ayn) - eye", "A deep throat sound unique to Arabic.", "alphabet"),
                        ("\u063a", "n", "ghayn (gh)", "\u063a\u064a\u0646", "\u063a\u0630\u0627\u0621 (ghidhaa\u02b9) - food", "Like French r.", "alphabet"),
                        ("\u0641", "n", "fa (f)", "\u0641\u0627\u0621", "\u0643\u062a\u0627\u0628 (kitaab) - book", "One dot above.", "alphabet"),
                    ], []),
                ]),
                ("Short Vowels", "Fatha, Kasra, Damma", [
                    ("Fatha, Kasra, Damma", "The three short vowels", [
                        ("\u064b", "n", "fatha (a)", "\u0641\u062a\u062d\u0629", "\u0643\u062a\u0628 (kataba) - he wrote", "A diagonal line above the letter.", "vowels"),
                        ("\u064c", "n", "damma (u)", "\u062f\u0645\u0629", "\u0643\u062a\u0628\u0648\u0627 (kataboo) - they wrote", "A small waw above the letter.", "vowels"),
                        ("\u064d", "n", "kasra (i)", "\u0643\u0633\u0631\u0629", "\u0643\u062a\u0628\u064a (kataba) - I wrote", "A diagonal line below the letter.", "vowels"),
                    ], [
                        mk_g(None, "Short Vowels in Arabic", "vowels",
                             "Arabic short vowels are written as diacritical marks above or below consonants.",
                             "Fatha (\u064b) = a: kataba (he wrote)\nDamma (\u064c) = u: katabu (they wrote)\nKasra (\u064d) = i: katabtu (I wrote)",
                             "In modern Arabic text, short vowels are often omitted.", "beginner"),
                    ]),
                    ("Sukun and Tanween", "Unvowelled and nunation", [
                        ("\u0652", "n", "sukun (no vowel)", "\u0633\u0643\u0648\u0646", "\u0645\u0643\u062a\u0628 (maktab) - office", "A circle above the letter indicating no vowel.", "vowels"),
                        ("\u064b", "n", "tanween fatha", "\u062a\u0646\u0648\u064a\u0646", "\u0643\u062a\u0627\u0628\u064b (kitaaban) - a book", "Indicates indefinite accusative.", "vowels"),
                    ], []),
                ]),
            ]),
            ("Beginner", "beginner", "Form 2", "Beginner / Madinah Book 2", "Build core vocabulary and grammar", [
                ("Noun Patterns", "Plurals and duals", [
                    ("Broken Plurals", "Irregular plurals", [
                        ("\u0643\u064a\u062a\u0627\u0628", "n", "book (singular)", "kitaab", "\u0643\u064a\u062a\u0627\u0628 (kitaab) - book", "One book.", "nouns"),
                        ("\u0643\u064a\u062a\u0628", "n", "books (plural)", "kutub", "\u0643\u062a\u0628 \u0643\u062b\u064a\u0631\u0629 (kutub katheera) - many books", "Broken plural pattern fu\u02b9l.", "nouns"),
                        ("\u0645\u0636\u0631\u0639", "n", "mosque", "masjid", "\u0627\u0644\u0645\u0636\u0631\u0639 (al-masjid) - the mosque", "Singular form.", "nouns"),
                        ("\u0645\u0636\u0627\u0631\u0639", "n", "mosques", "masaajid", "\u0645\u0636\u0627\u062c\u0639 \u0643\u062b\u064a\u0631\u0629 (masaajid katheera)", "Broken plural pattern mafaaji\u02b9l.", "nouns"),
                    ], [
                        mk_g(None, "Broken Plurals", "nouns",
                             "Arabic broken plurals change the internal vowel pattern of the singular noun.",
                             "Pattern fu\u02b9l: kitaab \u2192 kutub (books)\nPattern mafaaji\u02b9l: masjid \u2192 masaajid (mosques)\nThere are many patterns to memorise.",
                             "Unlike English, Arabic plurals change the word structure.", "intermediate"),
                    ]),
                    ("Dual Form", "Two of something", [
                        ("\u0643\u064a\u062a\u0627\u0628\u0627\u0646", "n", "two books", "kitaabaa\u02b9", "\u0639\u0646\u062f\u064a \u0643\u064a\u062a\u0627\u0628\u0627\u0646 (indi kitaabaa\u02b9) - I have two books", "Dual adds \u0627\u0646 to the end.", "nouns"),
                    ], []),
                ]),
                ("Pronouns & Sentences", "Building blocks", [
                    ("Personal Pronouns", "Subject pronouns", [
                        ("\u0623\u0646\u0627", "pronoun", "I", "an\u0601", "\u0623\u0646\u0627 \u0637\u0627\u0644\u0628 (an\u0601 ṭaalib) - I am a student", "First person singular.", "pronouns"),
                        ("\u0647\u0648\u0627", "pronoun", "he", "huwa", "\u0647\u0648\u0627 \u0645\u064f\u062f\u0631\u0633 (huwa mudarris) - He is a teacher", "Third person masculine.", "pronouns"),
                        ("\u0647\u064a", "pronoun", "she", "hiya", "\u0647\u064a \u0637\u0627\u0644\u0628\u0629 (hiya ṭaaliba) - She is a student", "Third person feminine.", "pronouns"),
                        ("\u0646\u062d\u0646\u064f", "pronoun", "we", "naḥnu", "\u0646\u062d\u0646\u064f \u0645\u0633\u0644\u0645\u0648\u0646 (naḥnu muslimoon) - We are Muslims", "First person plural.", "pronouns"),
                    ], [
                        mk_g(None, "Nominal Sentence \u0627\u0644\u062c\u0645\u0644\u0629 \u0627\u0644\u0627\u0633\u0645\u064a\u0629", "sentence_types",
                             "A nominal sentence begins with a noun/pronoun (subject) and a predicate.",
                             "An\u0601 ṭaalib - I am a student\nHuwa mudarris - He is a teacher\nNo verb 'to be' is needed in present tense.",
                             "Arabic has no present tense copula.", "beginner"),
                    ]),
                    ("Verbal Sentences", "VSO order", [], [
                        mk_g(None, "Verbal Sentence \u0627\u0644\u062c\u0645\u0644\u0629 \u0627\u0644\u0641\u0639\u0644\u064a\u0629", "sentence_types",
                             "A verbal sentence begins with the verb, followed by the subject and object.",
                             "Kataba al-waladu al-darsa - The boy wrote the lesson\nVerb-Subject-Object (VSO) order is default.",
                             "VSO is the default word order in Classical and Modern Standard Arabic.", "beginner"),
                    ]),
                ]),
            ]),
            ("Intermediate", "intermediate", "Form 3", "Intermediate / Madinah Book 3", "Master verb forms and case system", [
                ("Verb System", "Past, present, imperative", [
                    ("Past Tense (\u0627\u0644\u0645\u0627\u0636\u064a)", "Completed actions", [
                        ("\u0643\u062a\u0628\u064e", "verb", "he wrote", "kataba", "\u0643\u062a\u0628\u064e \u0627\u0644\u0648\u0644\u062f\u064f \u0627\u0644\u062f\u0631\u0633\u064e - The boy wrote the lesson", "Past tense is formed by adding prefixes/suffixes.", "verbs_past"),
                        ("\u0643\u062a\u0628\u062a\u064f", "verb", "I wrote", "katabtu", "\u0643\u062a\u0628\u062a\u064f \u0631\u0633\u0627\u0644\u0629 - I wrote a letter", "Subject pronouns are suffixes in past tense.", "verbs_past"),
                    ], [
                        mk_g(None, "Past Tense Formation", "verbs_past",
                             "Add subject suffixes to the past tense verb stem.",
                             "kataba (he wrote)\nkatabtu (I wrote)\nkatabna (we wrote)\nkatabtum (you pl. wrote)",
                             "Subject is indicated by suffixes, not separate pronouns.", "intermediate"),
                    ]),
                    ("Present Tense (\u0627\u0644\u0645\u0636\u0627\u0631\u0639)", "Ongoing actions", [
                        ("\u064a\u0643\u062a\u0628\u064f", "verb", "he writes", "yaktubu", "\u064a\u0643\u062a\u0628\u064f \u0627\u0644\u0637\u0627\u0644\u0628\u064f - The student writes", "Present tense has different patterns.", "verbs_present"),
                    ], []),
                ]),
                ("Case System", "The heart of Arabic grammar", [
                    ("Raf\u02bb (\u0631\u0641\u0639)", "Nominative case", [
                        ("\u0627\u0644\u0648\u0644\u062f\u064f", "n", "the boy (nominative)", "al-waladu", "\u062c\u0627\u0621\u064e \u0627\u0644\u0648\u0644\u062f\u064f - The boy came", "Subject takes raf\u02bb (damma ending).", "case_system"),
                    ], [
                        mk_g(None, "Case Endings (\u0627\u0644\u0625\u0639\u0631\u0627\u0628)", "case_system",
                             "Arabic nouns change their ending based on their grammatical role.",
                             "Raf\u02bb (nominative): al-waladu (the boy - subject)\nNaṣb (accusative): al-walada (the boy - object)\nJar\u02bb (genitive): waladi (of the boy - possessive)",
                             "Case endings are essential for understanding Arabic sentences.", "intermediate"),
                    ]),
                ]),
            ]),
            ("Upper Intermediate", "upper-intermediate", "Form 4", "Upper Intermediate", "Master complex grammar", [
                ("Derived Verb Forms", "The ten verb forms", [
                    ("Forms I-V", "Basic derivations", [
                        ("\u0643\u062a\u0628\u064e", "verb", "Form I - he wrote", "kataba", "\u0643\u062a\u0628\u064e - basic form: to write", "Form I is the base pattern.", "derived_verbs"),
                        ("\u0643\u062a\u0628\u064e", "verb", "Form II - he dictated", "kattaba", "\u0643\u0627\u062a\u0628\u064e - to dictate (Form II)", "Form II doubles the middle radical: causative/intensive.", "derived_verbs"),
                        ("\u0623\u0643\u062a\u0628\u064e", "verb", "Form III - he corresponded", "aaktaba", "\u0623\u0643\u062a\u0628\u064e - to correspond (Form III)", "Form III adds alif after first radical: reciprocal.", "derived_verbs"),
                        ("\u0623\u0643\u062a\u0628\u064e", "verb", "Form IV - he caused to write", "aktaba", "\u0623\u0643\u062a\u0628\u064e - to cause to write", "Form IV: causative.", "derived_verbs"),
                        ("\u062a\u0643\u0627\u062a\u0628\u064e", "verb", "Form V - he studied", "takattaba", "\u062a\u0643\u0627\u062a\u0628\u064e - to study (Form V)", "Form V: reflexive of Form II.", "derived_verbs"),
                    ], [
                        mk_g(None, "Arabic Verb Forms I-X", "derived_verbs",
                             "Arabic has ten standard verb forms derived from trilateral roots.",
                             "Form I: kataba (to write)\nForm II: kattaba (to dictate)\nForm III: aaktaba (to correspond)\nForm IV: aktaba (to cause to write)\nForm V: takattaba (to be written/correspond)",
                             "Each form adds specific meaning to the root k-t-b.", "intermediate"),
                    ]),
                ]),
                ("Connected Reading", "Real texts", [
                    ("Reading Skills", "Text comprehension", [], [
                        mk_g(None, "Reading Arabic Texts", "sentence_types",
                             "Arabic texts use connected script with optional vowel markings.",
                             "Reading without tashkeel (vowels) requires context knowledge\nPractice: Read the news, short stories, and Quranic passages",
                             "Reading skill improves dramatically with practice.", "intermediate"),
                    ]),
                ]),
            ]),
            ("Advanced", "advanced", "Advanced I", "Advanced Arabic", "Literary and formal Arabic", [
                ("Advanced Grammar", "Expert-level structures", [
                    ("Advanced \u0627\u0644\u0625\u0639\u0631\u0627\u0628", "Case system mastery", [], [
                        mk_g(None, "Advanced Case Endings", "case_system",
                             "Mastering all case rules including tamyeez, \u1e25aal, and istithnaa\u02b9.",
                             "Tamyeez: distinguishing specification\n\u1e24aal: circumstantial accusative\nIstithnaa\u02b9: exception constructions",
                             "These structures appear in formal and literary Arabic.", "advanced"),
                    ]),
                ]),
                ("Literary Arabic", "Classical beauty", [
                    ("Rhetoric (\u0627\u0644\u0628\u0644\u0627\u063a\u0629)", "The science of eloquence", [], [
                        mk_g(None, "Arabic Rhetoric (Bal\u0101ghah)", "literary",
                             "Arabic rhetoric encompasses metaphor (isti\u02b9aara), metonymy (maj\u00e1z), and other figures of speech.",
                             "Metaphor: al-wajhu qamarun - The face is a moon\nMetonymy:Reading the Book means studying the Quran",
                             "Bal\u0101ghah is considered the highest science in Arabic tradition.", "advanced"),
                    ]),
                ]),
            ]),
            ("Academic", "academic", "Advanced II", "Academic & Professional Arabic", "Master Arabic for professional contexts", [
                ("Professional Arabic", "Specialised registers", [
                    ("Business Arabic", "Commercial language", [], [
                        mk_g(None, "Business Arabic Vocabulary", "professional",
                             "Business Arabic uses formal vocabulary and specific terminology.",
                             "Contract: \u0639\u0642\u062f (aqd)\nClause: \u0634\u0631\u0637 (sharT)\nPartnership: \u0634\u0631\u0643\u0629 (sharika)",
                             "Register must match the formality of the context.", "advanced"),
                    ]),
                ]),
                ("Research & Translation", "Academic tools", [
                    ("Translation", "Cross-cultural communication", [], [
                        mk_g(None, "Translation Principles", "literary",
                             "Translation between Arabic and other languages requires cultural awareness.",
                             "Literal translation vs. dynamic equivalence\nArabic-English: consider idiom, register, and cultural context",
                             "Good translation is an art as well as a science.", "advanced"),
                    ]),
                ]),
            ]),
        ]

        for li, (lname, lslug, form, prof, ldesc, units_data) in enumerate(levels_data):
            level = LanguageLevel(
                language_id=lang.id, name=lname, slug=lslug,
                form_mapping=form, proficiency_label=prof, description=ldesc,
                order_index=li,
            )
            db.add(level)
            await db.flush()

            for ui, (uname, udesc, lessons_data) in enumerate(units_data):
                unit = LanguageUnit(
                    level_id=level.id, name=uname, description=udesc, order_index=ui,
                )
                db.add(unit)
                await db.flush()

                for lesi, item in enumerate(lessons_data):
                    les_title, les_desc = item[0], item[1]
                    vocab_data = item[2]
                    grammar_data = item[3] if len(item) > 3 else []

                    lesson = LanguageLesson(
                        unit_id=unit.id, title=les_title, description=les_desc,
                        lesson_type="grammar", order_index=lesi,
                    )
                    db.add(lesson)
                    await db.flush()

                    for vi, vtuple in enumerate(vocab_data):
                        diff = "beginner" if li < 2 else ("intermediate" if li < 4 else "advanced")
                        db.add(mk_v(lesson.id, vtuple[0], vtuple[1], vtuple[2],
                                    vtuple[3], vtuple[4], vtuple[5], vtuple[6], diff, vi))

                    for gi, g in enumerate(grammar_data):
                        if hasattr(g, 'lesson_id'):
                            g.lesson_id = lesson.id
                            g.order_index = gi
                            db.add(g)

        await db.commit()
'''

# Write files
for name, content in [("seed_chinese.py", chinese_code), ("seed_arabic.py", arabic_code)]:
    path = os.path.join(LANG_DIR, name)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.lstrip("\n"))
    print(f"Written: {name} ({os.path.getsize(path)} bytes)")

print("Done!")
