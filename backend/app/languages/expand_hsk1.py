"""Expand the HSK 1 (hsk1) level vocabulary toward the official 150-word set.

Idempotent: only inserts words whose character form is not already present in the
hsk1 level. Adds missing thematic units/lessons under the hsk1 level as needed.
Run automatically during backend startup (see app.main lifespan) and safe to call
repeatedly.
"""

from sqlalchemy import select

from app.database.engine import async_session
from app.models.languages import (
    Language,
    LanguageLesson,
    LanguageLevel,
    LanguageUnit,
    LanguageVocabulary,
)

# (word, translation, pinyin, part_of_speech, example_chinese, example_english, theme)
_UNITS = [
    (
        "People & Pronouns",
        "Family, people and personal pronouns",
        [
            (
                "Family Members",
                "Words for family and relationships",
                [
                    (
                        "爸爸",
                        "father / dad",
                        "bàba",
                        "n",
                        "我爸爸是老师。",
                        "My father is a teacher.",
                        "family",
                    ),
                    (
                        "妈妈",
                        "mother / mom",
                        "māma",
                        "n",
                        "我妈妈很漂亮。",
                        "My mother is very beautiful.",
                        "family",
                    ),
                    (
                        "哥哥",
                        "older brother",
                        "gēge",
                        "n",
                        "我哥哥比我大。",
                        "My older brother is older than me.",
                        "family",
                    ),
                    (
                        "姐姐",
                        "older sister",
                        "jiějie",
                        "n",
                        "姐姐是学生。",
                        "My older sister is a student.",
                        "family",
                    ),
                    (
                        "弟弟",
                        "younger brother",
                        "dìdi",
                        "n",
                        "我弟弟三岁。",
                        "My little brother is three years old.",
                        "family",
                    ),
                    (
                        "妹妹",
                        "younger sister",
                        "mèimei",
                        "n",
                        "妹妹喜欢唱歌。",
                        "My little sister likes to sing.",
                        "family",
                    ),
                    (
                        "儿子",
                        "son",
                        "érzi",
                        "n",
                        "他有一个儿子。",
                        "He has one son.",
                        "family",
                    ),
                    (
                        "女儿",
                        "daughter",
                        "nǚ'ér",
                        "n",
                        "她有一个女儿。",
                        "She has one daughter.",
                        "family",
                    ),
                    (
                        "丈夫",
                        "husband",
                        "zhàngfu",
                        "n",
                        "我丈夫在家。",
                        "My husband is at home.",
                        "family",
                    ),
                    (
                        "妻子",
                        "wife",
                        "qīzi",
                        "n",
                        "她妻子是医生。",
                        "His wife is a doctor.",
                        "family",
                    ),
                ],
            ),
            (
                "Pronouns & People",
                "Personal pronouns and common people",
                [
                    (
                        "他",
                        "he / him",
                        "tā",
                        "pronoun",
                        "他是我的同学。",
                        "He is my classmate.",
                        "people",
                    ),
                    (
                        "她",
                        "she / her",
                        "tā",
                        "pronoun",
                        "她喜欢看书。",
                        "She likes to read.",
                        "people",
                    ),
                    (
                        "它",
                        "it",
                        "tā",
                        "pronoun",
                        "它是我的猫。",
                        "It is my cat.",
                        "people",
                    ),
                    (
                        "我们",
                        "we / us",
                        "wǒmen",
                        "pronoun",
                        "我们去学校。",
                        "We are going to school.",
                        "people",
                    ),
                    (
                        "你们",
                        "you (plural)",
                        "nǐmen",
                        "pronoun",
                        "你们好！",
                        "Hello everyone!",
                        "people",
                    ),
                    (
                        "他们",
                        "they / them",
                        "tāmen",
                        "pronoun",
                        "他们是朋友。",
                        "They are friends.",
                        "people",
                    ),
                    (
                        "人",
                        "person / people",
                        "rén",
                        "n",
                        "那里有一个人。",
                        "There is a person over there.",
                        "people",
                    ),
                    (
                        "同学",
                        "classmate",
                        "tóngxué",
                        "n",
                        "他是我的同学。",
                        "He is my classmate.",
                        "school",
                    ),
                    (
                        "老师",
                        "teacher",
                        "lǎoshī",
                        "n",
                        "老师您好！",
                        "Hello, teacher!",
                        "school",
                    ),
                    (
                        "学生",
                        "student",
                        "xuésheng",
                        "n",
                        "我是学生。",
                        "I am a student.",
                        "school",
                    ),
                    (
                        "朋友",
                        "friend",
                        "péngyou",
                        "n",
                        "他是我的好朋友。",
                        "He is my good friend.",
                        "people",
                    ),
                ],
            ),
        ],
    ),
    (
        "Numbers & Quantifiers",
        "Numbers beyond ten and measure words",
        [
            (
                "Numbers 11+",
                "Large numbers and counting",
                [
                    (
                        "百",
                        "hundred",
                        "bǎi",
                        "num",
                        "一百个学生。",
                        "One hundred students.",
                        "numbers",
                    ),
                    (
                        "千",
                        "thousand",
                        "qiān",
                        "num",
                        "一本书一千块钱。",
                        "A book costs a thousand yuan.",
                        "numbers",
                    ),
                    (
                        "零",
                        "zero",
                        "líng",
                        "num",
                        "二零一零年。",
                        "Year 2010.",
                        "numbers",
                    ),
                    (
                        "岁",
                        "years old",
                        "suì",
                        "n",
                        "我十岁。",
                        "I am ten years old.",
                        "numbers",
                    ),
                    (
                        "个",
                        "a general measure word",
                        "gè",
                        "measure",
                        "一个苹果。",
                        "One apple.",
                        "measure",
                    ),
                    (
                        "些",
                        "some",
                        "xiē",
                        "measure",
                        "一些水。",
                        "Some water.",
                        "measure",
                    ),
                ],
            ),
        ],
    ),
    (
        "Time & Calendar",
        "Days, months and telling time",
        [
            (
                "Time of Day",
                "Parts of the day",
                [
                    (
                        "今天",
                        "today",
                        "jīntiān",
                        "n",
                        "今天很热。",
                        "Today is very hot.",
                        "time",
                    ),
                    (
                        "明天",
                        "tomorrow",
                        "míngtiān",
                        "n",
                        "明天见！",
                        "See you tomorrow!",
                        "time",
                    ),
                    (
                        "昨天",
                        "yesterday",
                        "zuótiān",
                        "n",
                        "昨天我去了学校。",
                        "Yesterday I went to school.",
                        "time",
                    ),
                    (
                        "现在",
                        "now",
                        "xiànzài",
                        "n",
                        "现在几点？",
                        "What time is it now?",
                        "time",
                    ),
                    (
                        "早上",
                        "morning",
                        "zǎoshang",
                        "n",
                        "早上好！",
                        "Good morning!",
                        "time",
                    ),
                    (
                        "中午",
                        "noon / midday",
                        "zhōngwǔ",
                        "n",
                        "中午我吃饭。",
                        "At noon I eat lunch.",
                        "time",
                    ),
                    (
                        "晚上",
                        "evening / night",
                        "wǎnshang",
                        "n",
                        "晚上我睡觉。",
                        "At night I sleep.",
                        "time",
                    ),
                    (
                        "时候",
                        "time / moment",
                        "shíhou",
                        "n",
                        "你来的时候告诉我。",
                        "Tell me when you come.",
                        "time",
                    ),
                ],
            ),
            (
                "Calendar",
                "Days, weeks, months and years",
                [
                    (
                        "年",
                        "year",
                        "nián",
                        "n",
                        "我今年二十岁。",
                        "I am twenty years old this year.",
                        "time",
                    ),
                    (
                        "月",
                        "month / moon",
                        "yuè",
                        "n",
                        "现在是九月。",
                        "It is September now.",
                        "time",
                    ),
                    (
                        "日",
                        "day / date",
                        "rì",
                        "n",
                        "今天是十日。",
                        "Today is the tenth.",
                        "time",
                    ),
                    (
                        "星期",
                        "week",
                        "xīngqī",
                        "n",
                        "今天是星期一。",
                        "Today is Monday.",
                        "time",
                    ),
                    (
                        "点",
                        "o'clock / hour",
                        "diǎn",
                        "n",
                        "现在一点。",
                        "It is one o'clock now.",
                        "time",
                    ),
                    (
                        "分",
                        "minute",
                        "fēn",
                        "n",
                        "现在一点十分。",
                        "It is ten past one.",
                        "time",
                    ),
                    (
                        "小时",
                        "hour",
                        "xiǎoshí",
                        "n",
                        "我学习了两个小时。",
                        "I studied for two hours.",
                        "time",
                    ),
                ],
            ),
        ],
    ),
    (
        "Action Verbs",
        "Common everyday verbs",
        [
            (
                "Movement & Daily Actions",
                "Frequent action words",
                [
                    (
                        "去",
                        "to go",
                        "qù",
                        "v",
                        "我去学校。",
                        "I am going to school.",
                        "verbs",
                    ),
                    (
                        "来",
                        "to come",
                        "lái",
                        "v",
                        "你来我家吧。",
                        "Come to my home.",
                        "verbs",
                    ),
                    (
                        "看",
                        "to look / watch / read",
                        "kàn",
                        "v",
                        "我看电视。",
                        "I watch TV.",
                        "verbs",
                    ),
                    (
                        "听",
                        "to listen",
                        "tīng",
                        "v",
                        "我听音乐。",
                        "I listen to music.",
                        "verbs",
                    ),
                    (
                        "说",
                        "to speak / say",
                        "shuō",
                        "v",
                        "你说中文吗？",
                        "Do you speak Chinese?",
                        "verbs",
                    ),
                    (
                        "读",
                        "to read",
                        "dú",
                        "v",
                        "我读报纸。",
                        "I read the newspaper.",
                        "verbs",
                    ),
                    (
                        "写",
                        "to write",
                        "xiě",
                        "v",
                        "我写汉字。",
                        "I write Chinese characters.",
                        "verbs",
                    ),
                    (
                        "学",
                        "to learn / study",
                        "xué",
                        "v",
                        "我学中文。",
                        "I learn Chinese.",
                        "verbs",
                    ),
                    (
                        "住",
                        "to live / stay",
                        "zhù",
                        "v",
                        "我住在北京。",
                        "I live in Beijing.",
                        "verbs",
                    ),
                    (
                        "工作",
                        "to work / job",
                        "gōngzuò",
                        "v",
                        "我爸爸工作很忙。",
                        "My father works hard.",
                        "verbs",
                    ),
                ],
            ),
            (
                "Desire, Possession & Actions",
                "Wants, having, and doing",
                [
                    (
                        "喜欢",
                        "to like",
                        "xǐhuan",
                        "v",
                        "我喜欢喝茶。",
                        "I like drinking tea.",
                        "verbs",
                    ),
                    (
                        "想",
                        "to want / think",
                        "xiǎng",
                        "v",
                        "我想喝水。",
                        "I want to drink water.",
                        "verbs",
                    ),
                    (
                        "要",
                        "to want / need",
                        "yào",
                        "v",
                        "我要一杯咖啡。",
                        "I want a cup of coffee.",
                        "verbs",
                    ),
                    (
                        "有",
                        "to have",
                        "yǒu",
                        "v",
                        "我有一本书。",
                        "I have a book.",
                        "verbs",
                    ),
                    (
                        "做",
                        "to do / make",
                        "zuò",
                        "v",
                        "我做作业。",
                        "I do homework.",
                        "verbs",
                    ),
                    ("买", "to buy", "mǎi", "v", "我买水果。", "I buy fruit.", "verbs"),
                    (
                        "卖",
                        "to sell",
                        "mài",
                        "v",
                        "他卖衣服。",
                        "He sells clothes.",
                        "verbs",
                    ),
                    (
                        "坐",
                        "to sit / take (transport)",
                        "zuò",
                        "v",
                        "我坐公共汽车。",
                        "I take the bus.",
                        "verbs",
                    ),
                    (
                        "走",
                        "to walk / go",
                        "zǒu",
                        "v",
                        "我们走吧。",
                        "Let's go.",
                        "verbs",
                    ),
                    (
                        "问",
                        "to ask",
                        "wèn",
                        "v",
                        "我问老师。",
                        "I ask the teacher.",
                        "verbs",
                    ),
                    (
                        "回答",
                        "to answer",
                        "huídá",
                        "v",
                        "请回答我的问题。",
                        "Please answer my question.",
                        "verbs",
                    ),
                ],
            ),
            (
                "Eating & Drinking",
                "Food and drink verbs",
                [
                    ("吃", "to eat", "chī", "v", "我吃米饭。", "I eat rice.", "food"),
                    ("喝", "to drink", "hē", "v", "我喝水。", "I drink water.", "food"),
                    (
                        "饭",
                        "meal / cooked rice",
                        "fàn",
                        "n",
                        "我吃饭了。",
                        "I have eaten.",
                        "food",
                    ),
                    (
                        "水",
                        "water",
                        "shuǐ",
                        "n",
                        "请给我一杯水。",
                        "Please give me a glass of water.",
                        "food",
                    ),
                    (
                        "茶",
                        "tea",
                        "chá",
                        "n",
                        "我喜欢中国茶。",
                        "I like Chinese tea.",
                        "food",
                    ),
                    (
                        "咖啡",
                        "coffee",
                        "kāfēi",
                        "n",
                        "我要一杯咖啡。",
                        "I want a cup of coffee.",
                        "food",
                    ),
                    (
                        "牛奶",
                        "milk",
                        "niúnǎi",
                        "n",
                        "我每天喝牛奶。",
                        "I drink milk every day.",
                        "food",
                    ),
                    (
                        "水果",
                        "fruit",
                        "shuǐguǒ",
                        "n",
                        "我喜欢吃水果。",
                        "I like eating fruit.",
                        "food",
                    ),
                    (
                        "苹果",
                        "apple",
                        "píngguǒ",
                        "n",
                        "一个苹果。",
                        "One apple.",
                        "food",
                    ),
                ],
            ),
        ],
    ),
    (
        "Places & Transport",
        "Locations and ways to get around",
        [
            (
                "Places",
                "Where things are",
                [
                    (
                        "学校",
                        "school",
                        "xuéxiào",
                        "n",
                        "我在学校。",
                        "I am at school.",
                        "places",
                    ),
                    (
                        "医院",
                        "hospital",
                        "yīyuàn",
                        "n",
                        "我去医院。",
                        "I am going to the hospital.",
                        "places",
                    ),
                    (
                        "商店",
                        "shop / store",
                        "shāngdiàn",
                        "n",
                        "商店开门了。",
                        "The store is open.",
                        "places",
                    ),
                    (
                        "家",
                        "home / family",
                        "jiā",
                        "n",
                        "我在家。",
                        "I am at home.",
                        "places",
                    ),
                    (
                        "中国",
                        "China",
                        "Zhōngguó",
                        "n",
                        "我学习汉语和中国文化。",
                        "I study Chinese language and culture.",
                        "places",
                    ),
                    (
                        "北京",
                        "Beijing",
                        "Běijīng",
                        "n",
                        "我去北京。",
                        "I am going to Beijing.",
                        "places",
                    ),
                    (
                        "地方",
                        "place",
                        "dìfang",
                        "n",
                        "这个地方很美。",
                        "This place is beautiful.",
                        "places",
                    ),
                ],
            ),
            (
                "Transport",
                "Getting around",
                [
                    (
                        "汽车",
                        "car",
                        "qìchē",
                        "n",
                        "我坐汽车去。",
                        "I go by car.",
                        "transport",
                    ),
                    (
                        "火车",
                        "train",
                        "huǒchē",
                        "n",
                        "火车来了。",
                        "The train is coming.",
                        "transport",
                    ),
                    (
                        "飞机",
                        "airplane",
                        "fēijī",
                        "n",
                        "我坐飞机去中国。",
                        "I fly to China.",
                        "transport",
                    ),
                    (
                        "出租车",
                        "taxi",
                        "chūzūchē",
                        "n",
                        "我打出租车。",
                        "I take a taxi.",
                        "transport",
                    ),
                    (
                        "公共汽车",
                        "bus",
                        "gōnggòng qìchē",
                        "n",
                        "公共汽车站。",
                        "The bus stop.",
                        "transport",
                    ),
                ],
            ),
        ],
    ),
    (
        "Question & Function Words",
        "Question words, particles and connectives",
        [
            (
                "Question Words",
                "Asking questions",
                [
                    (
                        "什么",
                        "what",
                        "shénme",
                        "pron",
                        "你叫什么名字？",
                        "What is your name?",
                        "question",
                    ),
                    ("谁", "who", "shéi", "pron", "他是谁？", "Who is he?", "question"),
                    (
                        "哪儿",
                        "where",
                        "nǎr",
                        "pron",
                        "你去哪儿？",
                        "Where are you going?",
                        "question",
                    ),
                    (
                        "哪",
                        "which",
                        "nǎ",
                        "pron",
                        "你是哪国人？",
                        "What country are you from?",
                        "question",
                    ),
                    (
                        "怎么",
                        "how",
                        "zěnme",
                        "pron",
                        "你怎么去？",
                        "How do you get there?",
                        "question",
                    ),
                    (
                        "为什么",
                        "why",
                        "wèishénme",
                        "pron",
                        "你为什么不来？",
                        "Why don't you come?",
                        "question",
                    ),
                    (
                        "几",
                        "how many (small number)",
                        "jǐ",
                        "pron",
                        "你家有几口人？",
                        "How many people are in your family?",
                        "question",
                    ),
                    (
                        "多少",
                        "how many / how much",
                        "duōshao",
                        "pron",
                        "多少钱？",
                        "How much is it?",
                        "question",
                    ),
                    (
                        "吗",
                        "question particle",
                        "ma",
                        "particle",
                        "你好吗？",
                        "How are you?",
                        "particle",
                    ),
                    (
                        "呢",
                        "question particle",
                        "ne",
                        "particle",
                        "你呢？",
                        "And you?",
                        "particle",
                    ),
                ],
            ),
            (
                "Function Words",
                "Particles and connectives",
                [
                    (
                        "的",
                        "possessive particle",
                        "de",
                        "particle",
                        "我的书。",
                        "My book.",
                        "particle",
                    ),
                    (
                        "了",
                        "completed action particle",
                        "le",
                        "particle",
                        "我来了。",
                        "I have arrived.",
                        "particle",
                    ),
                    (
                        "在",
                        "at / in / to be at",
                        "zài",
                        "prep",
                        "我在家。",
                        "I am at home.",
                        "preposition",
                    ),
                    (
                        "从",
                        "from",
                        "cóng",
                        "prep",
                        "我从英国来。",
                        "I come from England.",
                        "preposition",
                    ),
                    (
                        "到",
                        "to / arrive",
                        "dào",
                        "v",
                        "我到家了。",
                        "I have arrived home.",
                        "preposition",
                    ),
                    (
                        "和",
                        "and / with",
                        "hé",
                        "conj",
                        "我和他是朋友。",
                        "He and I are friends.",
                        "conjunction",
                    ),
                    (
                        "跟",
                        "with",
                        "gēn",
                        "prep",
                        "我跟你去。",
                        "I will go with you.",
                        "preposition",
                    ),
                    (
                        "都",
                        "all / both",
                        "dōu",
                        "adv",
                        "我们都是学生。",
                        "We are all students.",
                        "adverb",
                    ),
                    (
                        "也",
                        "also / too",
                        "yě",
                        "adv",
                        "我也喜欢。",
                        "I like it too.",
                        "adverb",
                    ),
                    (
                        "很",
                        "very",
                        "hěn",
                        "adv",
                        "我很高兴。",
                        "I am very happy.",
                        "adverb",
                    ),
                    ("太", "too / very", "tài", "adv", "太好了！", "Great!", "adverb"),
                ],
            ),
            (
                "Negation & More",
                "Negation and logical words",
                [
                    ("不", "not", "bù", "adv", "我不去。", "I am not going.", "adverb"),
                    (
                        "没",
                        "not (have)",
                        "méi",
                        "adv",
                        "我没有钱。",
                        "I do not have money.",
                        "adverb",
                    ),
                    (
                        "但",
                        "but",
                        "dàn",
                        "conj",
                        "我想去，但是没有时间。",
                        "I want to go, but I have no time.",
                        "conjunction",
                    ),
                    (
                        "因为",
                        "because",
                        "yīnwèi",
                        "conj",
                        "因为下雨了。",
                        "Because it is raining.",
                        "conjunction",
                    ),
                    (
                        "所以",
                        "so / therefore",
                        "suǒyǐ",
                        "conj",
                        "所以我不去。",
                        "So I am not going.",
                        "conjunction",
                    ),
                    (
                        "请",
                        "please / to invite",
                        "qǐng",
                        "v",
                        "请坐。",
                        "Please sit down.",
                        "verb",
                    ),
                ],
            ),
        ],
    ),
    (
        "Adjectives & States",
        "Descriptions and feelings",
        [
            (
                "Size & Quality",
                "Describing things",
                [
                    (
                        "大",
                        "big",
                        "dà",
                        "adj",
                        "这个苹果很大。",
                        "This apple is big.",
                        "adjectives",
                    ),
                    (
                        "小",
                        "small",
                        "xiǎo",
                        "adj",
                        "我的家很小。",
                        "My home is small.",
                        "adjectives",
                    ),
                    (
                        "多",
                        "many / much",
                        "duō",
                        "adj",
                        "我的书很多。",
                        "I have many books.",
                        "adjectives",
                    ),
                    (
                        "少",
                        "few / little",
                        "shǎo",
                        "adj",
                        "这里人很少。",
                        "There are very few people here.",
                        "adjectives",
                    ),
                    (
                        "好",
                        "good",
                        "hǎo",
                        "adj",
                        "这本书很好。",
                        "This book is good.",
                        "adjectives",
                    ),
                    (
                        "坏",
                        "bad",
                        "huài",
                        "adj",
                        "天气不好。",
                        "The weather is bad.",
                        "adjectives",
                    ),
                    (
                        "新",
                        "new",
                        "xīn",
                        "adj",
                        "这是我的新车。",
                        "This is my new car.",
                        "adjectives",
                    ),
                    (
                        "旧",
                        "old (used)",
                        "jiù",
                        "adj",
                        "这是一件旧衣服。",
                        "This is an old piece of clothing.",
                        "adjectives",
                    ),
                    (
                        "漂亮",
                        "pretty / beautiful",
                        "piàoliang",
                        "adj",
                        "你的衣服真漂亮！",
                        "Your clothes are really pretty!",
                        "adjectives",
                    ),
                ],
            ),
            (
                "Feelings & Conditions",
                "Emotions and states",
                [
                    (
                        "高兴",
                        "happy",
                        "gāoxìng",
                        "adj",
                        "我很高兴认识你。",
                        "I am happy to meet you.",
                        "emotions",
                    ),
                    (
                        "忙",
                        "busy",
                        "máng",
                        "adj",
                        "我今天很忙。",
                        "I am very busy today.",
                        "emotions",
                    ),
                    (
                        "累",
                        "tired",
                        "lèi",
                        "adj",
                        "我很累。",
                        "I am very tired.",
                        "emotions",
                    ),
                    (
                        "热",
                        "hot",
                        "rè",
                        "adj",
                        "今天很热。",
                        "Today is very hot.",
                        "adjectives",
                    ),
                    (
                        "冷",
                        "cold",
                        "lěng",
                        "adj",
                        "外面很冷。",
                        "It is cold outside.",
                        "adjectives",
                    ),
                    (
                        "快",
                        "fast / quick",
                        "kuài",
                        "adj",
                        "他跑得很快。",
                        "He runs fast.",
                        "adjectives",
                    ),
                    (
                        "慢",
                        "slow",
                        "màn",
                        "adj",
                        "请说慢一点。",
                        "Please speak a little slower.",
                        "adjectives",
                    ),
                ],
            ),
            (
                "Colors",
                "Common colors",
                [
                    (
                        "红",
                        "red",
                        "hóng",
                        "adj",
                        "她的鞋子是红的。",
                        "Her shoes are red.",
                        "colors",
                    ),
                    (
                        "黄",
                        "yellow",
                        "huáng",
                        "adj",
                        "我喜欢黄色的花。",
                        "I like yellow flowers.",
                        "colors",
                    ),
                    (
                        "蓝",
                        "blue",
                        "lán",
                        "adj",
                        "天空是蓝色的。",
                        "The sky is blue.",
                        "colors",
                    ),
                    (
                        "白",
                        "white",
                        "bái",
                        "adj",
                        "白色的纸。",
                        "White paper.",
                        "colors",
                    ),
                    (
                        "黑",
                        "black",
                        "hēi",
                        "adj",
                        "他的头发是黑的。",
                        "His hair is black.",
                        "colors",
                    ),
                    (
                        "绿",
                        "green",
                        "lǜ",
                        "adj",
                        "绿色的树叶。",
                        "Green leaves.",
                        "colors",
                    ),
                    (
                        "颜色",
                        "color",
                        "yánsè",
                        "n",
                        "你喜欢什么颜色？",
                        "What color do you like?",
                        "colors",
                    ),
                ],
            ),
        ],
    ),
    (
        "Health & Body",
        "Body and health vocabulary",
        [
            (
                "Body & Health",
                "Parts and wellness",
                [
                    (
                        "身体",
                        "body / health",
                        "shēntǐ",
                        "n",
                        "祝您身体健康。",
                        "Wish you good health.",
                        "health",
                    ),
                    (
                        "医生",
                        "doctor",
                        "yīshēng",
                        "n",
                        "我在看医生。",
                        "I am seeing a doctor.",
                        "health",
                    ),
                    (
                        "生病",
                        "to be ill",
                        "shēngbìng",
                        "v",
                        "我今天生病了。",
                        "I am ill today.",
                        "health",
                    ),
                    (
                        "头疼",
                        "headache",
                        "tóuténg",
                        "n",
                        "我头疼。",
                        "I have a headache.",
                        "health",
                    ),
                    (
                        "药",
                        "medicine",
                        "yào",
                        "n",
                        "我吃药了。",
                        "I took my medicine.",
                        "health",
                    ),
                    (
                        "休息",
                        "to rest",
                        "xiūxi",
                        "v",
                        "请好好休息。",
                        "Please rest well.",
                        "health",
                    ),
                    (
                        "睡觉",
                        "to sleep",
                        "shuìjiào",
                        "v",
                        "我晚上十点睡觉。",
                        "I go to sleep at ten at night.",
                        "health",
                    ),
                ],
            ),
        ],
    ),
    (
        "Daily Life & Miscellaneous",
        "Useful everyday vocabulary",
        [
            (
                "Daily Life",
                "Common words for daily activities",
                [
                    (
                        "手机",
                        "mobile phone",
                        "shǒujī",
                        "n",
                        "我的手机很新。",
                        "My phone is very new.",
                        "daily",
                    ),
                    (
                        "电脑",
                        "computer",
                        "diànnǎo",
                        "n",
                        "我在用电脑。",
                        "I am using the computer.",
                        "daily",
                    ),
                    (
                        "电视",
                        "television",
                        "diànshì",
                        "n",
                        "我看电视。",
                        "I watch TV.",
                        "daily",
                    ),
                    (
                        "衣服",
                        "clothes",
                        "yīfu",
                        "n",
                        "我买新衣服。",
                        "I buy new clothes.",
                        "daily",
                    ),
                    (
                        "钱",
                        "money",
                        "qián",
                        "n",
                        "我没有钱。",
                        "I do not have money.",
                        "daily",
                    ),
                    (
                        "书",
                        "book",
                        "shū",
                        "n",
                        "这是一本好书。",
                        "This is a good book.",
                        "daily",
                    ),
                    (
                        "名字",
                        "name",
                        "míngzi",
                        "n",
                        "你叫什么名字？",
                        "What is your name?",
                        "daily",
                    ),
                    (
                        "汉语",
                        "Chinese (language)",
                        "Hànyǔ",
                        "n",
                        "我学习汉语。",
                        "I study Chinese.",
                        "daily",
                    ),
                    (
                        "字",
                        "character / word",
                        "zì",
                        "n",
                        "这个字怎么写？",
                        "How do you write this character?",
                        "daily",
                    ),
                    (
                        "天气",
                        "weather",
                        "tiānqì",
                        "n",
                        "今天天气很好。",
                        "The weather is nice today.",
                        "daily",
                    ),
                    (
                        "下雨",
                        "to rain",
                        "xiàyǔ",
                        "v",
                        "外面下雨了。",
                        "It is raining outside.",
                        "daily",
                    ),
                ],
            ),
        ],
    ),
]


async def expand_hsk1():
    """Add official HSK 1 vocabulary to the chinese/hsk1 level (idempotent)."""
    async with async_session() as db:
        lang = (
            await db.execute(select(Language).where(Language.slug == "chinese"))
        ).scalar_one_or_none()
        if not lang:
            return
        level = (
            await db.execute(
                select(LanguageLevel).where(
                    LanguageLevel.language_id == lang.id, LanguageLevel.slug == "hsk1"
                )
            )
        ).scalar_one_or_none()
        if not level:
            return

        existing_words = {
            row[0]
            for row in (
                await db.execute(
                    select(LanguageVocabulary.word)
                    .join(
                        LanguageLesson,
                        LanguageVocabulary.lesson_id == LanguageLesson.id,
                    )
                    .join(LanguageUnit, LanguageLesson.unit_id == LanguageUnit.id)
                    .where(LanguageUnit.level_id == level.id)
                )
            ).all()
        }

        existing_units = {
            row[0]
            for row in (
                await db.execute(
                    select(LanguageUnit.name).where(LanguageUnit.level_id == level.id)
                )
            ).all()
        }

        max_unit_idx = (
            await db.execute(
                select(LanguageUnit.order_index)
                .where(LanguageUnit.level_id == level.id)
                .order_by(LanguageUnit.order_index.desc())
            )
        ).scalar() or 0

        changed = False
        for unit_name, unit_desc, lessons in _UNITS:
            if unit_name in existing_units:
                unit = (
                    await db.execute(
                        select(LanguageUnit).where(
                            LanguageUnit.level_id == level.id,
                            LanguageUnit.name == unit_name,
                        )
                    )
                ).scalar_one_or_none()
                max_lesson_idx = (
                    await db.execute(
                        select(LanguageLesson.order_index)
                        .where(LanguageLesson.unit_id == unit.id)
                        .order_by(LanguageLesson.order_index.desc())
                    )
                ).scalar() or 0
            else:
                max_unit_idx += 1
                unit = LanguageUnit(
                    level_id=level.id,
                    name=unit_name,
                    description=unit_desc,
                    order_index=max_unit_idx,
                )
                db.add(unit)
                await db.flush()
                max_lesson_idx = 0
                existing_units.add(unit_name)

            for les_idx, (les_title, les_desc, vocab) in enumerate(lessons):
                lesson = (
                    await db.execute(
                        select(LanguageLesson).where(
                            LanguageLesson.unit_id == unit.id,
                            LanguageLesson.title == les_title,
                        )
                    )
                ).scalar_one_or_none()
                if not lesson:
                    lesson = LanguageLesson(
                        unit_id=unit.id,
                        title=les_title,
                        description=les_desc,
                        lesson_type="vocabulary",
                        order_index=max_lesson_idx + 1,
                    )
                    db.add(lesson)
                    await db.flush()
                    max_lesson_idx += 1

                existing_in_lesson = {
                    row[0]
                    for row in (
                        await db.execute(
                            select(LanguageVocabulary.word).where(
                                LanguageVocabulary.lesson_id == lesson.id
                            )
                        )
                    ).all()
                }

                for v_idx, v in enumerate(vocab):
                    word, trans, pinyin, pos, ex, ex_trans, theme = v
                    if word in existing_words or word in existing_in_lesson:
                        continue
                    db.add(
                        LanguageVocabulary(
                            lesson_id=lesson.id,
                            word=word,
                            translation=trans,
                            pronunciation=pinyin,
                            part_of_speech=pos,
                            example_sentence=ex,
                            example_translation=ex_trans,
                            theme=theme,
                            difficulty="beginner",
                            order_index=v_idx,
                        )
                    )
                    changed = True

        if changed:
            await db.commit()
