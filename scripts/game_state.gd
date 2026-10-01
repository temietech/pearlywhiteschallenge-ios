# scripts/game_state.gd
extends Node

signal profile_changed(profile: Dictionary)
signal stats_updated(profile: Dictionary)
signal achievement_unlocked(achievement: Dictionary)
signal toast_pushed(toast: Dictionary)
signal level_up(level_data: Dictionary)

# Character Definitions
const CHARACTERS = [
	{"id": "chip", "name": "Chip", "color": "#7fd0ff", "unlock": "Starter", "job": "Student"},
	{"id": "flora", "name": "Flora", "color": "#ff9ec7", "unlock": "Starter", "job": "Botanist"},
	{"id": "dash", "name": "Dash", "color": "#7bffb1", "unlock": "7-day streak", "job": "Athlete"},
	{"id": "blaze", "name": "Blaze", "color": "#ff9a5a", "unlock": "Log 14 days", "job": "Secret Agent"},
	{"id": "ash", "name": "Ash", "color": "#bcb3ff", "unlock": "40 min brushed", "job": "Artist & Musician"},
	{"id": "penelope", "name": "Penelope", "color": "#ffd166", "unlock": "20 facts read", "job": "Fashion Designer"},
	{"id": "nibbles", "name": "Chef Nibbles", "color": "#f6a6ff", "unlock": "Beat 30 minions", "job": "Chef"},
	{"id": "spark", "name": "Spark", "color": "#a0e7ff", "unlock": "Perfect quiz", "job": "Scientist"},
	{"id": "sparkette", "name": "Sparkette", "color": "#ffb1e0", "unlock": "500 pts", "job": "Engineer"},
	{"id": "sircrown", "name": "Sir Crown", "color": "#ffd700", "unlock": "Dev Supporter", "job": "Royal Mascot"}
]

# Weapon Definitions
const WEAPONS = [
	{"id": "brush", "base": "Brush Boomerang", "emoji": "", "desc": "Faster swings and cleaner hits", "cost": 40},
	{"id": "paste", "base": "Paste Pistol", "emoji": "", "desc": "Wider spray radius", "cost": 60},
	{"id": "wash", "base": "Mouthwash Blast", "emoji": "", "desc": "Bigger splash zone", "cost": 80},
	{"id": "floss", "base": "Floss Lasso", "emoji": "", "desc": "Longer immobilize", "cost": 100}
]

# Player Levels (Calibrated for Day 24-25 Level 10 Pacing)
const PLAYER_LEVELS = [
	{"level": 1, "title": "Novice Brusher", "points": 0, "minutes": 0, "reward": 0},
	{"level": 2, "title": "Plaque Buster", "points": 500, "minutes": 8, "reward": 50},       # Day 2
	{"level": 3, "title": "Bristle Boss", "points": 1500, "minutes": 20, "reward": 100},     # Day 5
	{"level": 4, "title": "Floss Rookie", "points": 3200, "minutes": 32, "reward": 150},     # Day 8
	{"level": 5, "title": "Minty Master", "points": 5500, "minutes": 44, "reward": 200},     # Day 11
	{"level": 6, "title": "Cavity Crusher", "points": 8000, "minutes": 56, "reward": 250},   # Day 14
	{"level": 7, "title": "Fluoride Knight", "points": 11000, "minutes": 68, "reward": 300}, # Day 17
	{"level": 8, "title": "Enamel Elite", "points": 14000, "minutes": 78, "reward": 400},   # Day 20
	{"level": 9, "title": "Crown Champion", "points": 17000, "minutes": 88, "reward": 500},  # Day 22
	{"level": 10, "title": "Pearly Legend", "points": 20000, "minutes": 100, "reward": 1000} # Day 25 (100 mins total)
]

# Power-ups
const POWER_UPS = [
	{"id": "shield", "name": "Fluoride Shield", "image": "res://assets/images/shop/fluorideshield.png", "desc": "+20% Armour in Battles", "cost": 300, "currency": "points"},
	{"id": "multiplier", "name": "Coin Multiplier", "image": "res://assets/images/shop/coinmultiplier.png", "desc": "2x Coins for 24h", "cost": 400, "currency": "points"},
	{"id": "freeze", "name": "Streak Freeze", "image": "res://assets/images/shop/streakfreeze.png", "desc": "Saves a missed day", "cost": 500, "currency": "points"},
	{"id": "exchange", "name": "Points Bundle", "image": "res://assets/images/shop/pointsbundle.png", "desc": "Trade for 100 Points", "cost": 50, "currency": "coins"}
]

# Accessories
const ACCESSORIES = [
	{"id": "cap-green", "name": "Green Cap", "cost": 15, "emoji": ""},
	{"id": "crown", "name": "Royal Crown", "cost": 40, "emoji": ""},
	{"id": "shades", "name": "Shades", "cost": 20, "emoji": ""},
	{"id": "bow", "name": "Pink Bow", "cost": 15, "emoji": ""},
	{"id": "cape", "name": "Hero Cape", "cost": 55, "emoji": ""},
	{"id": "sparkle", "name": "Sparkle FX", "cost": 30, "emoji": ""}
]

# Dental Facts (Pediatric Guidelines - Days 1-28)
const FACTS = [
	"Brushing right before bed is the most important clean of the day!",
	"Your tooth enamel is the hardest substance in your whole body!",
	"Flossing cleans the tight spots between teeth that your toothbrush misses.",
	"Flossing before brushing clears space so toothpaste reaches everywhere.",
	"Good bacteria help your mouth, but bad bacteria eat sugar to make acid.",
	"Replace your toothbrush every 3 months or when bristles get bent.",
	"Chewing sugar-free gum makes extra saliva that washes away food.",
	"Cleaning your tongue removes bad-breath germs hiding in your mouth.",
	"Spit out toothpaste foam after brushing without rinsing with water!",
	"Drinking water washes away food bits and strengthens your teeth.",
	"Eating a slice of cheese reduces acid attacks and gives teeth calcium.",
	"Grinding teeth at night wears down enamel and makes your jaw sore.",
	"Baby teeth hold exact spaces open so adult teeth grow in straight.",
	"Kids only need a tiny pea-sized drop of fluoride toothpaste.",
	"Electric toothbrushes vibrate to remove more plaque than manual brushes.",
	"Sour sodas soften enamel, so wait 30 minutes before brushing!",
	"Crunchy raw carrots and apples scrub plaque away naturally.",
	"Smiling releases happy chemicals in your brain that boost your day!",
	"Healthy teeth help athletes breathe well and perform better in sports!",
	"Oral health affects your whole body and keeps you feeling strong!",
	"Saliva delivers minerals that constantly repair micro-scratches on teeth.",
	"Brush softly in small circles to keep your gums healthy and safe.",
	"Never share your toothbrush with anyone to avoid swapping germs.",
	"A dry mouth lets cavity bacteria multiply, so drink plenty of water.",
	"Pediatric dentists recommend your first checkup by your 1st birthday!",
	"Brush for 2 full minutes, twice a day, to stop cavities 100%!",
	"Floss every time you brush, between any teeth that touch each other.",
	"Brushing 2 minutes twice a day makes you a Pearly Whites Champion!"
]

# Storybook Chapters
const STORY = [
	{"day": 1, "title": "The Chase Begins", "panel": "Deep in a cave in Sweetmania, Blue Candor orders his candy minions to retrieve the second half of the map!", "img": "res://assets/images/scrapbook/StoryPanels/1_Start_Blue_Pursue.jpeg"},
	{"day": 2, "title": "Desperate Sprint", "panel": "The Molars sprint away from the cave, desperate to reach Mulinia as fast as they can!", "img": "res://assets/images/scrapbook/StoryPanels/2_Run.jpeg"},
	{"day": 3, "title": "Seeking Help", "panel": "In Sweetmania, they reach a gingerbread village and ask the locals to help hide them from Blue Candor!", "img": "res://assets/images/scrapbook/StoryPanels/3_Ask_gingerbread.jpeg"},
	{"day": 4, "title": "The Betrayal", "panel": "Penelope and Chip find a gingerbread man who, rather than wanting to help, tries to capture them for Blue Candor!", "img": "res://assets/images/scrapbook/StoryPanels/4_Gingerbread_Chase_.jpeg"},
	{"day": 5, "title": "Peppermint Shield", "panel": "As the gingerbread man closes in, brave Blaze uses a peppermint as a shield to protect his friends!", "img": "res://assets/images/scrapbook/StoryPanels/5_Peppermint_Defense_.jpeg"},
	{"day": 6, "title": "The Crossroads", "panel": "Suddenly, the Molars arrive at a crossroads, but Spark uses his cyborg eye to calculate the shortest route!", "img": "res://assets/images/scrapbook/StoryPanels/6_Crossroads.jpeg"},
	{"day": 7, "title": "Chocolate Blockade", "panel": "The Molars attempt to take another shortcut, only to find their path blocked by a rushing chocolate river!", "img": "res://assets/images/scrapbook/StoryPanels/7_Choco_River.jpeg"},
	{"day": 8, "title": "Fountain Hideout", "panel": "The crew hides behind a chocolate fountain as Blue Candor's candy minions march past!", "img": "res://assets/images/scrapbook/StoryPanels/8_Fountain_Hiding.jpeg"},
	{"day": 9, "title": "Ambush at the Border", "panel": "At the bridge connecting Sweetmania to the Fruit Kingdom, Blue Candor and his minions ambush the Molars!", "img": "res://assets/images/scrapbook/StoryPanels/9_First_Candy_Combat.jpeg"},
	{"day": 10, "title": "Fruit Energy", "panel": "After defeating Blue Candor, the Molars arrive in Fruitland and boost their energy with some delicious fruit!", "img": "res://assets/images/scrapbook/StoryPanels/10_Energy_Refill_Fruit.jpeg"},
	{"day": 11, "title": "Banana House", "panel": "The molars take cover inside a banana house while more of Blue Candor's minions march by on the hunt!", "img": "res://assets/images/scrapbook/StoryPanels/11_Friendly_Banana.jpeg"},
	{"day": 12, "title": "Uncharted Water", "panel": "Continuing their journey, they reach an unfenced body of water and realise they must proceed with caution!", "img": "res://assets/images/scrapbook/StoryPanels/12_Unchartered_Waters.jpeg"},
	{"day": 13, "title": "Colorful Fish", "panel": "Blaze and Penelope take a moment to admire the happy, colorful fish swimming safely in the water!", "img": "res://assets/images/scrapbook/StoryPanels/13_See_some_fish.jpeg"},
	{"day": 14, "title": "Hidden Trap", "panel": "Sparkette spots a hidden trap placed by Blue Candor and quickly warns the rest of the group!", "img": "res://assets/images/scrapbook/StoryPanels/14_Trap.jpeg"},
	{"day": 15, "title": "Cotton Fur", "panel": "Ash notices a small tuft of Blue Candor's fur, signaling that the villain is lurking nearby!", "img": "res://assets/images/scrapbook/StoryPanels/15_Spot_Blue_Fur.jpeg"},
	{"day": 16, "title": "River Dive", "panel": "In a desperate attempt to evade the approaching candy soldiers, the Molars dive right into the river!", "img": "res://assets/images/scrapbook/StoryPanels/16_Hide_in_water.jpeg"},
	{"day": 17, "title": "Veggie Village", "panel": "Washing ashore at Veggie Village, Chef Nibbles is absolutely delighted to spot some giant, fresh tomatoes!", "img": "res://assets/images/scrapbook/StoryPanels/17_Veggie_Village.jpeg"},
	{"day": 18, "title": "Mushroom Seeds", "panel": "The owner of the mushroom house gifts Flora a pouch of flower seeds, which she cannot wait to plant!", "img": "res://assets/images/scrapbook/StoryPanels/18_Flora_Seeds.jpeg"},
	{"day": 19, "title": "Blocked beside the Pond!", "panel": "As the Molars prepare to leave Fruitland, Blue Candor and his minions block their path once more to try and steal the map!", "img": "res://assets/images/scrapbook/StoryPanels/19_Second_Candy_Combat.jpeg"},
	{"day": 20, "title": "Running Free", "panel": "After defeating Blue Candor yet again, the Molars resume their journey, sprinting away as fast as their legs can carry them!", "img": "res://assets/images/scrapbook/StoryPanels/20_Run_for_it.jpeg"},
	{"day": 21, "title": "Climbing Up", "panel": "The crew helps one another climb a tall tree to see just how far away Mulinia is!", "img": "res://assets/images/scrapbook/StoryPanels/21_Help_eachother_up.jpeg"},
	{"day": 22, "title": "Super Vision", "panel": "Using his super-zoom vision, Spark happily announces that Mulinia is not too far away!", "img": "res://assets/images/scrapbook/StoryPanels/22_Scouting.jpeg"},
	{"day": 23, "title": "Planting Seeds", "panel": "Ash and Flora find a beautiful clearing and plant the seeds gifted at the mushroom windmill!", "img": "res://assets/images/scrapbook/StoryPanels/23_Plant_Seeds.jpeg"},
	{"day": 24, "title": "Water from the well", "panel": "Spotting a drinking well, the Molars take the opportunity to rehydrate for the final leg of their journey!", "img": "res://assets/images/scrapbook/StoryPanels/24_Drinking_Well.jpeg"},
	{"day": 25, "title": "Caterpillar Sighting", "panel": "To avoid an incoming army of candy minions, the Molars hide inside a dense bush, where Penelope spots a little caterpillar!", "img": "res://assets/images/scrapbook/StoryPanels/25_Caterpillar_in_hiding.jpeg"},
	{"day": 26, "title": "Icy Butterfly", "panel": "Now clear of Blue Candor's minions, the crew marvels at an icy blue butterfly, a creature native only to the Enamel Forest!", "img": "res://assets/images/scrapbook/StoryPanels/26_Frosty_Butterfly.jpeg"},
	{"day": 27, "title": "Approaching Mulinia", "panel": "The Molars rejoice, knowing the frosty environment means they are merely seconds away from Mulinia!", "img": "res://assets/images/scrapbook/StoryPanels/27_Near_Mulinia.jpeg"},
	{"day": 28, "title": "Safe Arrival", "panel": "After a long, exhausting, and difficult journey, the Molars safely deliver the map and are joined by Ezumi, the chief guardian fairy of the Enamel Clan!", "img": "res://assets/images/scrapbook/StoryPanels/28_Finish.jpeg"}
]
const STORIES = STORY

# Weekly Quiz Banks
const QUIZ_BANKS = [
	# Week 1 (Day 7 Node) - 7 Recap + 7 Preview
	[
		{"day": 1, "section": "RECAP", "q": "Brushing right before bed is the most important clean of the day.", "a": true, "why": "At night there is no saliva to fight bacteria, so teeth need extra protection!", "tip": "Brush right before bed, and remember: spit, don't rinse!"},
		{"day": 2, "section": "RECAP", "q": "Your tooth enamel is the hardest substance in your whole body.", "a": true, "why": "Enamel cannot regrow once it's gone!", "tip": "Brush gently twice a day with fluoride toothpaste to strengthen your enamel."},
		{"day": 3, "section": "RECAP", "q": "A toothbrush alone cleans 100% of every tooth surface.", "a": false, "why": "A toothbrush misses up to 40% of surfaces between teeth!", "tip": "Floss every time you brush, between any teeth that touch."},
		{"day": 4, "section": "RECAP", "q": "Flossing before brushing helps toothpaste reach everywhere.", "a": true, "why": "Flossing clears out tight spaces so fluoride toothpaste can reach between teeth!", "tip": "Floss first to clear spaces, then brush with fluoride toothpaste!"},
		{"day": 5, "section": "RECAP", "q": "Bad bacteria eat sugar to make cavity acid.", "a": true, "why": "Bad bacteria feed on sugar and produce acid that hurts enamel!", "tip": "Drink water after sweet treats to wash away sugar!"},
		{"day": 6, "section": "RECAP", "q": "You should change your toothbrush every 3 months.", "a": true, "why": "Bent bristles clean poorly, so swap your brush every 3 months!", "tip": "Replace your toothbrush every 3 months or when bristles bend!"},
		{"day": 7, "section": "RECAP", "q": "Chewing sugar-free gum can help fight cavities.", "a": true, "why": "Gum makes extra saliva that washes away food and acid!", "tip": "Chew sugar-free gum after meals when you cannot brush!"},
		{"day": 8, "section": "PREVIEW", "q": "Where do bad-breath germs hide in your mouth?", "concept": "Tongue Germs", "tip": "Gently scrape your tongue back to front every morning!"},
		{"day": 9, "section": "PREVIEW", "q": "What should you do after brushing with toothpaste?", "concept": "Spit Don't Rinse", "tip": "Spit out the toothpaste foam, but do not rinse with water!"},
		{"day": 10, "section": "PREVIEW", "q": "What drink cleans leftover food off your teeth?", "concept": "Water Hydration", "tip": "Drink water with meals to flush away leftover food!"},
		{"day": 11, "section": "PREVIEW", "q": "How does eating a slice of cheese help your teeth?", "concept": "Cheese Calcium", "tip": "Eat a small piece of cheese after meals to reduce acid attacks!"},
		{"day": 12, "section": "PREVIEW", "q": "What happens if you grind your teeth at night?", "concept": "Teeth Grinding", "tip": "Tell your dentist if you wake up with sore teeth or jaws!"},
		{"day": 13, "section": "PREVIEW", "q": "Why are baby teeth important if they fall out later?", "concept": "Baby Teeth", "tip": "Take great care of baby teeth so adult teeth grow in straight!"},
		{"day": 14, "section": "PREVIEW", "q": "How much toothpaste should kids put on their toothbrush?", "concept": "Pea Sized Paste", "tip": "Use a small pea-sized dot of fluoride toothpaste!"}
	],
	# Week 2 (Day 14 Node) - 7 Recap + 7 Preview
	[
		{"day": 8, "section": "RECAP", "q": "Cleaning your tongue removes bad-breath germs.", "a": true, "why": "Your tongue holds germs that need a gentle scrape!", "tip": "Gently sweep your tongue scraper back to front every morning!"},
		{"day": 9, "section": "RECAP", "q": "You should rinse with lots of water right after brushing.", "a": false, "why": "Rinsing with water washes away the protective fluoride layer!", "tip": "Spit out the foam, but don't rinse with water!"},
		{"day": 10, "section": "RECAP", "q": "Drinking water after meals helps rinse teeth.", "a": true, "why": "Water flushes leftover food away so bacteria cannot make acid!", "tip": "Drink water with every meal to keep teeth clean!"},
		{"day": 11, "section": "RECAP", "q": "Eating cheese reduces acid attacks in your mouth.", "a": true, "why": "Cheese reduces acid attacks and gives teeth rich calcium!", "tip": "Eat a small piece of cheese as a healthy snack after treats!"},
		{"day": 12, "section": "RECAP", "q": "Grinding teeth at night wears down enamel.", "a": true, "why": "Grinding puts big pressure on teeth and wears down enamel!", "tip": "Tell your dentist if you wake up with sore jaws!"},
		{"day": 13, "section": "RECAP", "q": "Baby teeth don't matter because adult teeth replace them.", "a": false, "why": "Baby teeth keep spaces ready so adult teeth grow in straight!", "tip": "Brush baby teeth carefully every single day!"},
		{"day": 14, "section": "RECAP", "q": "Kids only need a pea-sized drop of toothpaste.", "a": true, "why": "A small pea-sized drop gives the right amount of fluoride!", "tip": "Use a pea-sized dot of fluoride toothpaste every time!"},
		{"day": 15, "section": "PREVIEW", "q": "Why do electric toothbrushes clean plaque so well?", "concept": "Electric Brushes", "tip": "Let electric brush bristles do the spinning work!"},
		{"day": 16, "section": "PREVIEW", "q": "Why should you wait 30 minutes after soda to brush?", "concept": "Acid Softening", "tip": "Swish water after soda, then wait 30 minutes to brush!"},
		{"day": 17, "section": "PREVIEW", "q": "Which crunchy snacks act like natural toothbrushes?", "concept": "Crunchy Veggies", "tip": "Snack on crisp apples, carrots, and celery to clean teeth!"},
		{"day": 18, "section": "PREVIEW", "q": "What happens in your brain when you smile?", "concept": "Smiling Power", "tip": "Smile big every day to release happy chemicals in your brain!"},
		{"day": 19, "section": "PREVIEW", "q": "How does good oral health help athletes in sports?", "concept": "Sports Performance", "tip": "Keep your teeth healthy so you can perform your best in sports!"},
		{"day": 20, "section": "PREVIEW", "q": "How does oral health affect your overall body health?", "concept": "Overall Health", "tip": "Taking care of your teeth keeps your whole body strong!"},
		{"day": 21, "section": "PREVIEW", "q": "What natural liquid in your mouth protects teeth?", "concept": "Saliva Defense", "tip": "Drink water so your body can make plenty of protective saliva!"}
	],
	# Week 3 (Day 21 Node) - 7 Recap + 7 Preview
	[
		{"day": 15, "section": "RECAP", "q": "Electric brushes remove more plaque than manual brushes.", "a": true, "why": "Micro-vibrations break up sticky plaque quickly and easily!", "tip": "Let the electric brush glide gently across each tooth!"},
		{"day": 16, "section": "RECAP", "q": "You should brush right away after drinking sour soda.", "a": false, "why": "Sour drinks soften enamel, so brushing right away scrubs enamel off!", "tip": "Swish water after acidic drinks, then wait 30 minutes to brush!"},
		{"day": 17, "section": "RECAP", "q": "Crunchy raw vegetables help clean your teeth as you chew.", "a": true, "why": "Crunchy fibers scrub teeth and boost cleansing saliva!", "tip": "Snack on crisp carrots, celery, or apples!"},
		{"day": 18, "section": "RECAP", "q": "Smiling releases happy chemicals in your brain.", "a": true, "why": "Smiling triggers your brain to feel happier and less stressed!", "tip": "Share your Pearly Whites smile every day!"},
		{"day": 19, "section": "RECAP", "q": "Healthy teeth help athletes perform better in sports.", "a": true, "why": "Pain-free teeth and healthy mouth breathing improve energy and focus!", "tip": "Keep teeth strong for peak sports performance!"},
		{"day": 20, "section": "RECAP", "q": "Oral health affects your whole body and overall health.", "a": true, "why": "Healthy teeth stop bad germs from spreading to the rest of your body!", "tip": "Brush daily to keep your whole body feeling strong!"},
		{"day": 21, "section": "RECAP", "q": "Saliva delivers minerals to repair micro-scratches on teeth.", "a": true, "why": "Saliva washes away food and delivers minerals to rebuild enamel!", "tip": "Drink water so saliva can protect your teeth!"},
		{"day": 22, "section": "PREVIEW", "q": "What motion should you use when brushing teeth?", "concept": "Circular Motion", "tip": "Brush softly using small, gentle circular motions!"},
		{"day": 23, "section": "PREVIEW", "q": "Why should you never share your toothbrush with anyone?", "concept": "Brush Hygiene", "tip": "Always use your own toothbrush to avoid swapping germs!"},
		{"day": 24, "section": "PREVIEW", "q": "Why does a dry mouth make it easier for cavities to grow?", "concept": "Dry Mouth Risk", "tip": "Drink water during play and bedtime to prevent dry mouth!"},
		{"day": 25, "section": "PREVIEW", "q": "When should a child have their first dentist checkup?", "concept": "First Visit", "tip": "Visit your dentist by your 1st birthday or 1st tooth!"},
		{"day": 26, "section": "PREVIEW", "q": "How many minutes should you brush your teeth each day?", "concept": "2 Minute Rule", "tip": "Brush for 2 full minutes morning and night!"},
		{"day": 27, "section": "PREVIEW", "q": "How often should you floss between teeth that touch?", "concept": "Flossing Habit", "tip": "Floss every time you brush, between touching teeth!"},
		{"day": 28, "section": "PREVIEW", "q": "How do you become a Pearly Whites Champion?", "concept": "Champion Habit", "tip": "Keep up your daily 2-minute brushing habit every day!"}
	],
	# Week 4 (Day 28 Node - Final Quiz) - exactly 7 questions
	[
		{"day": 28, "section": "CHAMPION", "q": "You should brush your teeth for 2 minutes, twice a day.", "a": true, "why": "Two minutes morning and night removes plaque and stops cavities!", "tip": "Brush for 2 full minutes every morning and night!"},
		{"day": 28, "section": "CHAMPION", "q": "Flossing every time you brush cleans the spaces your brush cannot reach.", "a": true, "why": "Floss gets between tight teeth where bristles can't fit!", "tip": "Floss every time you brush, between touching teeth!"},
		{"day": 28, "section": "CHAMPION", "q": "It is fine to share your toothbrush with a friend.", "a": false, "why": "Toothbrushes hold germs, so sharing swaps bacteria between mouths!", "tip": "Always keep your toothbrush to yourself!"},
		{"day": 28, "section": "CHAMPION", "q": "You should brush right away after drinking a sour, fizzy soda.", "a": false, "why": "Sour drinks soften enamel, so wait 30 minutes and swish water first!", "tip": "Swish water after acidic drinks, then wait to brush!"},
		{"day": 28, "section": "CHAMPION", "q": "Crunchy fruit and veggies help keep your teeth clean.", "a": true, "why": "Crunchy fibers scrub teeth and boost cleansing saliva!", "tip": "Snack on crisp carrots, celery, or apples!"},
		{"day": 28, "section": "CHAMPION", "q": "Visiting your dentist regularly helps keep your smile healthy.", "a": true, "why": "Early and regular checkups catch small problems before they grow!", "tip": "Visit your dentist every 6 months!"},
		{"day": 28, "section": "CHAMPION", "q": "You are a Pearly Whites Champion!", "a": true, "why": "You brushed, flossed and learned for 28 whole days. Congratulations, Champion!", "tip": "Keep up your daily 2-minute brushing habit for a lifetime of smiles!"}
	]
]

# Tiered Badges
const BADGE_FAMILIES = [
	{"family": "streak", "name": "On a Roll", "emoji": "", "tiers": [{"level": 1, "threshold": 3, "label": "3-day streak"}, {"level": 2, "threshold": 7, "label": "7-day streak"}, {"level": 3, "threshold": 14, "label": "14-day streak"}]},
	{"family": "fact", "name": "Fact Finder", "emoji": "", "tiers": [{"level": 1, "threshold": 5, "label": "5 facts"}, {"level": 2, "threshold": 10, "label": "10 facts"}, {"level": 3, "threshold": 20, "label": "20 facts"}]},
	{"family": "minion", "name": "Minion Masher", "emoji": "", "tiers": [{"level": 1, "threshold": 25, "label": "25 minions"}, {"level": 2, "threshold": 75, "label": "75 minions"}, {"level": 3, "threshold": 200, "label": "200 minions"}]},
	{"family": "quiz", "name": "Quiz Whiz", "emoji": "", "tiers": [{"level": 1, "threshold": 1, "label": "1 quiz"}, {"level": 2, "threshold": 2, "label": "2 quizzes"}, {"level": 3, "threshold": 3, "label": "3 quizzes"}]},
	{"family": "boss", "name": "Sweet Defeat", "emoji": "", "tiers": [{"level": 1, "threshold": 1, "label": "Defeat Blue Candor"}, {"level": 2, "threshold": 2, "label": "Defeat 2 times"}, {"level": 3, "threshold": 3, "label": "Defeat 3 times"}]},
	{"family": "coin", "name": "Coin Collector", "emoji": "", "tiers": [{"level": 1, "threshold": 250, "label": "Save 250 coins"}, {"level": 2, "threshold": 750, "label": "Save 750 coins"}, {"level": 3, "threshold": 2000, "label": "Save 2000 coins"}]},
	{"family": "point", "name": "Point Master", "emoji": "", "tiers": [{"level": 1, "threshold": 500, "label": "500 points"}, {"level": 2, "threshold": 2000, "label": "2000 points"}, {"level": 3, "threshold": 5000, "label": "5000 points"}]}
]

const SAVE_PATH = "user://pearly_whites_save.json"

# State Store
var profiles: Array[Dictionary] = []
var active_id: String = ""
var family_mode: bool = false
var family_competition_winner: String = ""
var dev_mode: bool = false
var tooth_fairy_pin: String = ""
var brush_check_failed_attempts: int = 0
var privacy_policy_agreed: bool = false

# Firebase & Cloud Sync State
var family_code: String = ""
var cloud_sync_enabled: bool = true
var firebase_db_url: String = "https://pearly-whites-challenge-default-rtdb.firebaseio.com/families"
var http_client: HTTPRequest

signal cloud_synced(success: bool)

func _ready():
	_setup_http_client()
	load_game()

func _setup_http_client():
	if not http_client:
		http_client = HTTPRequest.new()
		http_client.name = "FirebaseHTTP"
		add_child(http_client)

func save_data():
	save_game()

func save_profiles():
	save_game()

func save_game():
	var save_dict = {
		"profiles": profiles,
		"active_id": active_id,
		"family_mode": family_mode,
		"family_competition_winner": family_competition_winner,
		"family_code": family_code,
		"tooth_fairy_pin": tooth_fairy_pin,
		"privacy_policy_agreed": privacy_policy_agreed
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "  "))
		file.flush()
		file.close()
	
	if family_code != "" and cloud_sync_enabled and http_client != null and http_client.is_inside_tree():
		sync_family_to_cloud()

	var fb_mgr = get_node_or_null("/root/FirebaseManager")
	if fb_mgr and fb_mgr.has_method("save_challenge_data"):
		fb_mgr.save_challenge_data(get_progress_dict())


func set_tooth_fairy_pin(pin: String):
	tooth_fairy_pin = pin.strip_edges()
	save_game()

func get_tooth_fairy_pin() -> String:
	return tooth_fairy_pin

func has_tooth_fairy_pin() -> bool:
	return tooth_fairy_pin.strip_edges().length() == 4

func verify_tooth_fairy_pin(pin: String) -> bool:
	return has_tooth_fairy_pin() and pin.strip_edges() == tooth_fairy_pin

func reset_all_data():
	profiles.clear()
	active_id = ""
	family_mode = false
	family_code = ""
	family_competition_winner = ""
	tooth_fairy_pin = ""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FirebaseManager and FirebaseManager.has_method("delete_user_account_and_data"):
		FirebaseManager.delete_user_account_and_data()
	save_game()
	profile_changed.emit({})
	push_toast("Data Reset", "All game data and profiles have been cleared.", "", "blue")

func leave_family_code():
	family_code = ""
	family_mode = false
	save_game()
	push_toast("Left Family", "Disconnected from family group.", "", "orange")

func create_family_code() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	family_code = code
	family_mode = true
	save_game()
	sync_family_to_cloud()
	push_toast("Family Code Created!", "Your code: " + family_code, "", "green")
	return family_code

func join_family_code(target_code: String):
	target_code = target_code.strip_edges().to_upper()
	if target_code.length() == 0:
		push_toast("Invalid Code", "Please enter a valid family code.", "", "red")
		return
	
	family_code = target_code
	family_mode = true
	save_game()
	fetch_family_from_cloud()
	push_toast("Joined Family!", "Connected to family: " + family_code, "", "green")

func sync_family_to_cloud():
	if family_code == "":
		return
	var payload = {
		"code": family_code,
		"profiles": profiles,
		"last_updated": Time.get_unix_time_from_system()
	}
	var json_body = JSON.stringify(payload)
	var url = "%s/%s.json" % [firebase_db_url, family_code]
	var headers = ["Content-Type: application/json"]
	if http_client:
		http_client.request(url, headers, HTTPClient.METHOD_PUT, json_body)

func fetch_family_from_cloud():
	if family_code == "":
		return
	var url = "%s/%s.json" % [firebase_db_url, family_code]
	if http_client:
		http_client.request_completed.connect(_on_family_cloud_fetched, CONNECT_ONE_SHOT)
		http_client.request(url, [], HTTPClient.METHOD_GET)

func _on_family_cloud_fetched(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY and data.has("profiles"):
				var cloud_profiles = data["profiles"]
				if typeof(cloud_profiles) == TYPE_ARRAY:
					for cp in cloud_profiles:
						var found = false
						for lp in profiles:
							if lp["id"] == cp["id"]:
								found = true
								# Merge higher score/progress
								lp["points"] = max(int(lp.get("points", 0)), int(cp.get("points", 0)))
								lp["streak"] = max(int(lp.get("streak", 0)), int(cp.get("streak", 0)))
								lp["currentNode"] = max(int(lp.get("currentNode", 1)), int(cp.get("currentNode", 1)))
								break
						if not found:
							profiles.append(_sanitize_profile(cp))
					save_game()
					cloud_synced.emit(true)

func _sanitize_profile(p: Dictionary) -> Dictionary:
	if p.is_empty():
		return p
	var int_keys = [
		"points", "coins", "streak", "currentNode", "age",
		"totalMinutes", "factsRead", "minionsDefeated", "bossesDefeated",
		"playerLevel", "totalBrushingSeconds", "cavityLevel"
	]
	for k in int_keys:
		if p.has(k):
			p[k] = int(round(float(p[k])))
	if not p.has("ammo") or typeof(p["ammo"]) != TYPE_DICTIONARY:
		p["ammo"] = {"brushes": 10, "battery": 0, "tubes": 0, "spools": 0, "vials": 0}
	else:
		for ak in p["ammo"]:
			p["ammo"][ak] = int(round(float(p["ammo"][ak])))
			
	# Ensure weaponTiers dictionary exists with valid arrays and clean unique integers
	if not p.has("weaponTiers") or typeof(p["weaponTiers"]) != TYPE_DICTIONARY:
		p["weaponTiers"] = {"brush": [1], "paste": [], "wash": [], "floss": []}
	for wk in ["brush", "paste", "wash", "floss"]:
		var raw_t: Array = p["weaponTiers"].get(wk, []) if typeof(p["weaponTiers"].get(wk, [])) == TYPE_ARRAY else []
		var clean_tiers: Array = []
		for t in raw_t:
			var t_int = int(round(float(t)))
			if t_int >= 1 and t_int <= 3 and not clean_tiers.has(t_int):
				clean_tiers.append(t_int)
		if wk == "brush" and not clean_tiers.has(1):
			clean_tiers.append(1)
		p["weaponTiers"][wk] = clean_tiers

	# Synchronize weaponLevels with weaponTiers so unowned weapons don't incorrectly show 1/3 owned
	if not p.has("weaponLevels") or typeof(p["weaponLevels"]) != TYPE_DICTIONARY:
		p["weaponLevels"] = {"brush": 1, "paste": 0, "wash": 0, "floss": 0}
	for wk in ["brush", "paste", "wash", "floss"]:
		var tiers: Array = p["weaponTiers"].get(wk, [])
		if tiers.is_empty():
			p["weaponLevels"][wk] = 1 if wk == "brush" else 0
		else:
			var max_lvl = 0
			for t in tiers:
				if int(t) > max_lvl:
					max_lvl = int(t)
			p["weaponLevels"][wk] = max(max_lvl, 1 if wk == "brush" else 0)
			
	# Node synchronization logic

	var cur_node = int(p.get("currentNode", 0))
	var cur_day = day_for_node(cur_node)
	var morning_done_for_cur_day = is_day_morning_brush_done(cur_day, p)
	
	# Sync factsCollected with brushing progress: any day with daysStatus == "done" earns its fact.
	# Also cap at max_allowed so no future facts appear.
	var max_allowed_fact_idx = (cur_day - 1) if morning_done_for_cur_day else max(-1, cur_day - 2)
	var days_status = p.get("daysStatus", [])
	var clean_facts: Array = []
	# Backfill from daysStatus first
	for ds_idx in range(min(days_status.size(), 28)):
		var fi = min(FACTS.size() - 1, ds_idx)
		if str(days_status[ds_idx]) == "done" and fi <= max_allowed_fact_idx and not clean_facts.has(fi):
			clean_facts.append(fi)
	# Also keep any explicitly-collected facts within bounds
	for f in p.get("factsCollected", []):
		var f_int = int(f)
		if f_int >= 0 and f_int <= max_allowed_fact_idx and not clean_facts.has(f_int):
			clean_facts.append(f_int)
	p["factsCollected"] = clean_facts
	p["factsRead"] = clean_facts.size()
	
	# Sanitize unlockedStory & seen_story_unlocks: preserve player seen history without pre-filling
	var max_allowed_story = cur_day if morning_done_for_cur_day else max(0, cur_day - 1)
	var clean_story: Array = []
	for st in p.get("unlockedStory", []):
		var st_int = int(st)
		if st_int >= 1 and st_int <= max_allowed_story and not clean_story.has(st_int):
			clean_story.append(st_int)
	p["unlockedStory"] = clean_story

	var seen_story = p.get("seen_story_unlocks", [])
	if typeof(seen_story) != TYPE_ARRAY:
		seen_story = []
	var clean_seen_story: Array = []
	for st in seen_story:
		var st_int = int(st)
		if st_int >= 1 and st_int <= max_allowed_story and not clean_seen_story.has(st_int):
			clean_seen_story.append(st_int)
	p["seen_story_unlocks"] = clean_seen_story

	# Sanitize seen_weapon_unlocks
	var weapon_defs = [
		{"id": "brush_1", "unlock_day": 1},
		{"id": "paste_1", "unlock_day": 2},
		{"id": "brush_2", "unlock_day": 3},
		{"id": "floss_1", "unlock_day": 5},
		{"id": "wash_1", "unlock_day": 7},
		{"id": "paste_2", "unlock_day": 9},
		{"id": "brush_3", "unlock_day": 11},
		{"id": "floss_2", "unlock_day": 13},
		{"id": "paste_3", "unlock_day": 15},
		{"id": "wash_2", "unlock_day": 17},
		{"id": "floss_3", "unlock_day": 19},
		{"id": "wash_3", "unlock_day": 21}
	]
	var seen_weapons = p.get("seen_weapon_unlocks", [])
	if typeof(seen_weapons) != TYPE_ARRAY:
		seen_weapons = ["brush", "brush_1"]
	else:
		seen_weapons = seen_weapons.duplicate()
	if not seen_weapons.has("brush"):
		seen_weapons.append("brush")
	if not seen_weapons.has("brush_1"):
		seen_weapons.append("brush_1")
	var cur_node_day = day_for_node(int(p.get("currentNode", 1)))
	var effective_day = max(cur_node_day, get_unlocked_day(p))
			
	var clean_seen_weapons: Array = []
	for sw in seen_weapons:
		var sw_str = str(sw)
		var keep = true
		for w_def in weapon_defs:
			if w_def["id"] == sw_str and int(w_def["unlock_day"]) > effective_day:
				keep = false
				break
		if keep and not clean_seen_weapons.has(sw_str):
			clean_seen_weapons.append(sw_str)
	p["seen_weapon_unlocks"] = clean_seen_weapons

	# Ensure weapons/tiers are valid integers between 1-3 (do NOT prune based on day:
	# once a tier is purchased and saved, it stays owned permanently)
	var w_tiers = p.get("weaponTiers", {})
	if typeof(w_tiers) == TYPE_DICTIONARY:
		for wk in ["brush", "paste", "wash", "floss"]:
			var user_tiers = w_tiers.get(wk, [])
			if typeof(user_tiers) == TYPE_ARRAY:
				var filtered_tiers: Array = []
				for t in user_tiers:
					var t_int = int(t)
					if t_int >= 1 and t_int <= 3 and not filtered_tiers.has(t_int):
						filtered_tiers.append(t_int)
				if wk == "brush" and not filtered_tiers.has(1):
					filtered_tiers.append(1)
				filtered_tiers.sort()
				w_tiers[wk] = filtered_tiers
				var max_lvl = 1 if wk == "brush" else 0
				for ft in filtered_tiers:
					max_lvl = max(max_lvl, int(ft))
				if not p.has("weaponLevels") or typeof(p["weaponLevels"]) != TYPE_DICTIONARY:
					p["weaponLevels"] = {}
				p["weaponLevels"][wk] = max_lvl
				if p.has("loadout") and typeof(p["loadout"]) == TYPE_DICTIONARY:
					if int(p["loadout"].get(wk, 0)) > max_lvl:
						p["loadout"][wk] = max_lvl

	# Ensure character unlocks & seen tracking are accurate
	if not p.has("unlockedCharacters") or typeof(p["unlockedCharacters"]) != TYPE_ARRAY:
		p["unlockedCharacters"] = ["chip", "flora"]
	for starter in ["chip", "flora"]:
		if not p["unlockedCharacters"].has(starter):
			p["unlockedCharacters"].append(starter)
			
	if not p.has("seen_character_unlocks") or typeof(p["seen_character_unlocks"]) != TYPE_ARRAY:
		p["seen_character_unlocks"] = ["chip", "flora"]
	for starter in ["chip", "flora"]:
		if not p["seen_character_unlocks"].has(starter):
			p["seen_character_unlocks"].append(starter)
			
	# Ensure persistent queues and fail-safe records exist
	if not p.has("queued_notifications") or typeof(p["queued_notifications"]) != TYPE_ARRAY:
		p["queued_notifications"] = []
	if not p.has("queued_achievements") or typeof(p["queued_achievements"]) != TYPE_ARRAY:
		p["queued_achievements"] = []
	if not p.has("notified_streak_milestones") or typeof(p["notified_streak_milestones"]) != TYPE_ARRAY:
		p["notified_streak_milestones"] = []
	if not p.has("delivered_notifications") or typeof(p["delivered_notifications"]) != TYPE_DICTIONARY:
		p["delivered_notifications"] = {}
	if not p.has("baseline_quiz_answers") or typeof(p["baseline_quiz_answers"]) != TYPE_ARRAY:
		p["baseline_quiz_answers"] = []
		
	check_character_unlocks(p, false)
	
	# Normalize booster timestamps & cooldowns
	var cur_unix = Time.get_unix_time_from_system()
	var mult_until = float(p.get("multiplierActiveUntil", 0))
	if mult_until > 100000000000.0:
		mult_until = mult_until / 1000.0
	if mult_until <= cur_unix:
		p["multiplierActiveUntil"] = 0.0
	else:
		p["multiplierActiveUntil"] = mult_until
		
	var last_frz = float(p.get("lastFreezePurchase", 0))
	if last_frz > 100000000000.0:
		last_frz = last_frz / 1000.0
	p["lastFreezePurchase"] = last_frz

	# Heal progression if user completed Day 2 evening (Node 4) but finish_node wasn't called:
	if cur_node == 4:
		if days_status.size() >= 2 and days_status[1] == "done":
			p["currentNode"] = 5
			p["streak"] = max(int(p.get("streak", 0)), 2)
			if not p.has("nodeStage") or typeof(p["nodeStage"]) != TYPE_DICTIONARY:
				p["nodeStage"] = {}
			p["nodeStage"]["4"] = 99

	p["queued_notifications"] = []
			
	return p

func is_multiplier_active(p: Dictionary = {}) -> bool:
	var profile = p if not p.is_empty() else get_active_profile()
	if profile.is_empty():
		return false
	var until = float(profile.get("multiplierActiveUntil", 0))
	if until > 100000000000.0:
		until = until / 1000.0
	return until > Time.get_unix_time_from_system()


var NODE_DATA: Array[Dictionary] = []

const BONUS_MINIGAME_DAYS = [2, 5, 8, 13, 16, 20, 24, 27]
const BONUS_QUIZ_DAYS = [7, 14, 21, 28]
const FINAL_QUIZ_DAY = 28

func _init_nodes():
	NODE_DATA.clear()
	NODE_DATA.append({"id": 0, "day": 0, "type": "intro"})
	var node_id = 1
	for day in range(1, 29):
		NODE_DATA.append({"id": node_id, "day": day, "type": "morning"})
		node_id += 1
		# Day 28 order: AM brush > Final Quiz > PM brush (Candy Crusade is its last step) > story panel > FINISH
		if day == FINAL_QUIZ_DAY:
			NODE_DATA.append({"id": node_id, "day": day, "type": "quiz"})
			node_id += 1
		NODE_DATA.append({"id": node_id, "day": day, "type": "evening"})
		node_id += 1
		if BONUS_MINIGAME_DAYS.has(day):
			NODE_DATA.append({"id": node_id, "day": day, "type": "minigame"})
			node_id += 1
		if BONUS_QUIZ_DAYS.has(day) and day != FINAL_QUIZ_DAY:
			NODE_DATA.append({"id": node_id, "day": day, "type": "quiz"})
			node_id += 1
	NODE_DATA.append({"id": node_id, "day": 28, "type": "finish"})

# Candy Crusade fights happen at the evening node of days 1, 9, 19, 28 (node 0 is only prologue + quiz).
# The Nth fight the player reaches plays Level N (capped at the last level, 4).
const CANDY_CRUSADE_DAYS: Array = [1, 9, 19, 28]

func get_candy_crusade_number(node_id: int) -> int:
	if NODE_DATA.is_empty():
		_init_nodes()
	var count: int = 0
	var last: int = mini(node_id, NODE_DATA.size() - 1)
	for i in range(0, last + 1):
		var d: Dictionary = NODE_DATA[i]
		var t: String = str(d.get("type", ""))
		if (t == "evening" and CANDY_CRUSADE_DAYS.has(int(d.get("day", 0)))):
			count += 1
	return maxi(count, 1)

func get_node_data(node_id: int) -> Dictionary:
	if NODE_DATA.is_empty():
		_init_nodes()
	if node_id >= 0 and node_id < NODE_DATA.size():
		return NODE_DATA[node_id]
	return {"id": node_id, "day": clamp(int(ceil(float(node_id) / 2.0)), 0, 28), "type": "morning"}

func day_for_node(node_id: int) -> int:
	return get_node_data(node_id).get("day", 0)

func get_unlocked_day(p: Dictionary = {}) -> int:
	var profile = p if not p.is_empty() else get_active_profile()
	if profile.is_empty():
		return 1
	var cur_node = int(profile.get("currentNode", 1))
	var cur_day = day_for_node(cur_node)
	if cur_day <= 0:
		return 0
	var morning_done = is_day_morning_completed(cur_day, profile)
	return cur_day if morning_done else max(0, cur_day - 1)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var test_json_conv = JSON.new()
		var error = test_json_conv.parse(json_str)
		if error == OK:
			var data = test_json_conv.data
			if typeof(data) == TYPE_DICTIONARY:
				profiles.clear()
				for p in data.get("profiles", []):
					profiles.append(_sanitize_profile(p))
				active_id = data.get("active_id", "")
				family_mode = data.get("family_mode", false)
				family_competition_winner = data.get("family_competition_winner", "")
				family_code = data.get("family_code", "")
				tooth_fairy_pin = data.get("tooth_fairy_pin", "")
				privacy_policy_agreed = data.get("privacy_policy_agreed", false)

func get_profiles() -> Array[Dictionary]:
	return profiles

func get_active_profile() -> Dictionary:
	for p in profiles:
		if p["id"] == active_id:
			return _sanitize_profile(p)
	if profiles.size() > 0:
		active_id = profiles[0]["id"]
		return _sanitize_profile(profiles[0])
	return {}

func get_coins() -> int:
	return int(round(float(get_active_profile().get("coins", 0))))

func get_points() -> int:
	return int(round(float(get_active_profile().get("points", 0))))

func get_streak() -> int:
	return int(round(float(get_active_profile().get("streak", 0))))

func get_avatar() -> String:
	return str(get_active_profile().get("avatar", "chip"))

func get_profile_name() -> String:
	return str(get_active_profile().get("name", "Champion"))


func get_category_for_age(age: int) -> String:
	if age <= 6:
		return "Junior"
	if age <= 12:
		return "Kid"
	return "Adult"

func get_age_default_difficulty(age: int) -> String:
	if age <= 6:
		return "easy"
	if age <= 12:
		return "medium"
	return "hard"

func get_difficulty() -> String:
	var p = get_active_profile()
	if p.has("difficulty") and str(p["difficulty"]) in ["easy", "medium", "hard"]:
		return str(p["difficulty"])
	var age = int(p.get("age", 8))
	return get_age_default_difficulty(age)

func set_difficulty(diff: String):
	if diff in ["easy", "medium", "hard"]:
		update_active_profile({"difficulty": diff})

func make_new_profile(name: String, avatar: String, age: int = 8) -> Dictionary:
	var cat = get_category_for_age(age)
	var diff = get_age_default_difficulty(age)
	var new_p = {
		"id": str(randi()) + "_" + str(Time.get_unix_time_from_system()),
		"name": name.strip_edges() if name.strip_edges() != "" else "Player",
		"avatar": avatar,
		"age": age,
		"category": cat,
		"difficulty": diff,
		"currentNode": 0,
		"points": 0,
		"coins": 0,
		"streak": 0,
		"totalMinutes": 0,
		"factsRead": 0,
		"minionsDefeated": 0,
		"bossesDefeated": 0,
		"unlockedCharacters": ["chip", "flora"],
		"weaponLevels": {"brush": 1, "paste": 0, "wash": 0, "floss": 0},
		"weaponTiers": {"brush": [1], "paste": [], "wash": [], "floss": []},
		"ammo": {"brushes": 10, "battery": 0, "tubes": 0, "spools": 0, "vials": 0},
		"loadout": {"brush": 1, "paste": 0, "wash": 0, "floss": 0},
		"ownedAccessories": [],
		"equippedAccessory": "",
		"daysStatus": [],
		"lastBrushDate": "",
		"factsCollected": [],
		"quizPerfect": false,
		"quizzesCompleted": 0,
		"cavityLevel": 0,
		"muted": false,
		"ttsEnabled": false,
		"tutorial_done": false,
		"candyTrapPending": false,
		"earnedBadges": [],
		"storyRead": [],
		"unlockedFacts": [],
		"unlockedStory": [],
		"baseline_quiz_answers": [],
		"memoryBest": 999,
		"bestBubblePop": 0,
		"inventory": {"shield": 0, "freeze": 0},
		"multiplierActiveUntil": 0,
		"nodeStage": {},
		"playerLevel": 1,
		"lastMiniGame": {"memory": 0, "bubble": 0}
	}
	for i in range(28):
		new_p["daysStatus"].append("todo")
	return new_p

func add_profile(name: String, avatar: String, age: int = 8) -> String:
	if profiles.size() >= 5:
		return active_id
	var p = make_new_profile(name, avatar, age)
	profiles.append(p)
	if active_id == "":
		active_id = p["id"]
	save_game()
	profile_changed.emit(p)
	return p["id"]

func set_active_profile(id: String):
	active_id = id
	var p = get_active_profile()
	save_game()
	profile_changed.emit(p)

func remove_profile(id: String):
	for i in range(profiles.size()):
		if profiles[i]["id"] == id:
			profiles.remove_at(i)
			break
	if active_id == id:
		active_id = profiles[0]["id"] if profiles.size() > 0 else ""
	save_game()
	profile_changed.emit(get_active_profile())

func rename_profile(id: String, new_name: String, avatar: String, age: int = -1):
	for p in profiles:
		if p["id"] == id:
			p["name"] = new_name
			p["avatar"] = avatar
			if age > 0:
				p["age"] = age
				p["category"] = get_category_for_age(age)
				if not p.has("difficulty") or p["difficulty"] == "":
					p["difficulty"] = get_age_default_difficulty(age)
			save_game()
			profile_changed.emit(p)
			break

func update_active_profile(patch: Dictionary):
	var p = get_active_profile()
	if p.is_empty():
		return
	for k in patch:
		if k in ["points", "coins", "streak", "currentNode", "age", "playerLevel", "totalMinutes", "factsRead", "minionsDefeated", "bossesDefeated", "totalBrushingSeconds", "cavityLevel"]:
			p[k] = int(round(float(patch[k])))
		else:
			p[k] = patch[k]
	_sanitize_profile(p)
	check_character_unlocks(p, true)
	check_level_up(p)
	save_game()
	stats_updated.emit(p)
	profile_changed.emit(p)

func level_for_points(points: int, profile: Dictionary = {}) -> Dictionary:
	var cur = PLAYER_LEVELS[0]
	var mins = get_total_brushing_minutes(profile) if not profile.is_empty() else 0
	for l in PLAYER_LEVELS:
		var req_pts = int(l.get("points", 0))
		var req_mins = int(l.get("minutes", 0))
		if points >= req_pts and mins >= req_mins:
			cur = l
	return cur

func check_level_up(p: Dictionary):
	var reached = level_for_points(int(round(float(p.get("points", 0)))), p)
	var known = int(round(float(p.get("playerLevel", 1))))
	if reached["level"] > known:
		var coin_reward = 0
		for l in PLAYER_LEVELS:
			if l["level"] > known and l["level"] <= reached["level"]:
				coin_reward += int(round(float(l["reward"])))
		p["playerLevel"] = reached["level"]
		p["coins"] = int(round(float(p.get("coins", 0)))) + coin_reward
		save_game()
		level_up.emit(reached)
		push_achievement("Level Up!", "Level %d - %s" % [reached["level"], reached["title"]], "Reached %d points!" % reached["points"], coin_reward)

func check_character_unlocks(p: Dictionary = {}, notify: bool = true) -> Array[String]:
	if p.is_empty():
		p = get_active_profile()
	if p.is_empty():
		return []
		
	if not p.has("unlockedCharacters") or typeof(p["unlockedCharacters"]) != TYPE_ARRAY:
		p["unlockedCharacters"] = ["chip", "flora"]
		
	for starter in ["chip", "flora"]:
		if not p["unlockedCharacters"].has(starter):
			p["unlockedCharacters"].append(starter)
			
	var newly_unlocked: Array[String] = []
	
	var streak = int(round(float(p.get("streak", 0))))
	var cur_node = int(round(float(p.get("currentNode", 1))))
	var done_days = 0
	if p.has("daysStatus") and typeof(p["daysStatus"]) == TYPE_ARRAY:
		for ds in p["daysStatus"]:
			if str(ds) == "done":
				done_days += 1
	var total_mins = get_total_brushing_minutes(p)
	var facts_cnt = p.get("factsCollected", []).size() if typeof(p.get("factsCollected", [])) == TYPE_ARRAY else int(round(float(p.get("factsRead", 0))))
	var minions = int(round(float(p.get("minionsDefeated", 0))))
	var quiz_perf = bool(p.get("quizPerfect", false)) or bool(p.get("quiz_perfect", false))
	var pts = int(round(float(p.get("points", 0))))
	
	var unlock_rules = [
		{
			"id": "dash",
			"name": "Dash",
			"cond": streak >= 7,
			"desc": "Unlocked with a 7-day brushing streak!",
			"coins": 50
		},
		{
			"id": "blaze",
			"name": "Blaze",
			"cond": (streak >= 14 or done_days >= 14 or cur_node >= 29),
			"desc": "Unlocked by completing 14 days!",
			"coins": 50
		},
		{
			"id": "ash",
			"name": "Ash",
			"cond": total_mins >= 40,
			"desc": "Unlocked at 40 total minutes brushed!",
			"coins": 50
		},
		{
			"id": "penelope",
			"name": "Penelope",
			"cond": facts_cnt >= 20,
			"desc": "Unlocked at 20 dental facts collected!",
			"coins": 50
		},
		{
			"id": "nibbles",
			"name": "Chef Nibbles",
			"cond": minions >= 30,
			"desc": "Unlocked by defeating 30 cavity minions!",
			"coins": 50
		},
		{
			"id": "spark",
			"name": "Spark",
			"cond": quiz_perf,
			"desc": "Unlocked with a perfect quiz score!",
			"coins": 100
		},
		{
			"id": "sparkette",
			"name": "Sparkette",
			"cond": pts >= 500,
			"desc": "Unlocked at 500 total Star Points!",
			"coins": 50
		}
	]
	
	for rule in unlock_rules:
		var c_id = str(rule["id"])
		var is_unlocked = p["unlockedCharacters"].has(c_id)
		
		if not p.has("seen_character_unlocks") or typeof(p["seen_character_unlocks"]) != TYPE_ARRAY:
			p["seen_character_unlocks"] = ["chip", "flora"]
		var is_seen = p["seen_character_unlocks"].has(c_id)
		
		if rule["cond"]:
			if not is_unlocked:
				p["unlockedCharacters"].append(c_id)
				newly_unlocked.append(c_id)
				
			# Fail-safe: If unlocked and user hasn't seen the celebration modal yet
			if not is_seen and notify:
				# Check if already queued to prevent duplicates
				var already_queued = false
				var q_achs = p.get("queued_achievements", [])
				for existing in q_achs:
					if existing.get("char_id", "") == c_id:
						already_queued = true
						break
				if not already_queued:
					push_achievement("New Champion!", "%s has joined your team!" % rule["name"], rule["desc"], rule["coins"], c_id)
					push_toast("Avatar Unlocked!", "%s is now available in Character Select!" % rule["name"], "", "green", "avatar_unlocked_" + c_id)
				
	check_badge_unlocks(p, notify)
	return newly_unlocked

func check_badge_unlocks(p: Dictionary = {}, notify: bool = true):
	if p.is_empty():
		p = get_active_profile()
	if p.is_empty():
		return
		
	if not p.has("seen_badge_unlocks") or typeof(p["seen_badge_unlocks"]) != TYPE_DICTIONARY:
		p["seen_badge_unlocks"] = {}
		
	var streak = int(round(float(p.get("streak", 0))))
	var facts_cnt = p.get("factsCollected", []).size() if typeof(p.get("factsCollected", [])) == TYPE_ARRAY else int(round(float(p.get("factsRead", 0))))
	var minions = int(round(float(p.get("minionsDefeated", 0))))
	var quizzes = int(round(float(p.get("quizzesCompleted", 0))))
	var bosses = int(round(float(p.get("bossesDefeated", 0))))
	var coins = int(round(float(p.get("coins", 0))))
	var pts = int(round(float(p.get("points", 0))))
	
	var days_stat = p.get("daysStatus", [])
	var has_done = false
	var completed_days = 0
	if typeof(days_stat) == TYPE_ARRAY:
		for d in days_stat:
			if d == "done" or d == "surprise-done":
				has_done = true
				completed_days += 1
	var sparkle_cnt = 1 if (has_done or int(p.get("totalMinutes", 0)) >= 2) else 0

	var badge_evals = [
		{"id": "streak", "name": "ON A ROLL", "val": streak, "tiers": [{"lvl": 1, "th": 3, "label": "3-Day Streak", "img": "res://assets/images/badgescreen/onaroll_bronze.png"}, {"lvl": 2, "th": 7, "label": "7-Day Streak", "img": "res://assets/images/badgescreen/onaroll_silver.png"}, {"lvl": 3, "th": 14, "label": "14-Day Streak", "img": "res://assets/images/badgescreen/onaroll_gold.png"}]},
		{"id": "fact", "name": "FACT FINDER", "val": facts_cnt, "tiers": [{"lvl": 1, "th": 5, "label": "5 Facts Learned", "img": "res://assets/images/badgescreen/factfinder_bronze.png"}, {"lvl": 2, "th": 10, "label": "10 Facts Learned", "img": "res://assets/images/badgescreen/factfinder_silver.png"}, {"lvl": 3, "th": 20, "label": "20 Facts Learned", "img": "res://assets/images/badgescreen/factfinder_gold.png"}]},
		{"id": "minion", "name": "MINION MASHER", "val": minions, "tiers": [{"lvl": 1, "th": 25, "label": "25 Minions Defeated", "img": "res://assets/images/badgescreen/minionmasher_bronze.png"}, {"lvl": 2, "th": 75, "label": "75 Minions Defeated", "img": "res://assets/images/badgescreen/minionmasher_silver.png"}, {"lvl": 3, "th": 200, "label": "200 Minions Defeated", "img": "res://assets/images/badgescreen/minionmasher_gold.png"}]},
		{"id": "quiz", "name": "QUIZ WHIZ", "val": quizzes, "tiers": [{"lvl": 1, "th": 1, "label": "1 Quiz Completed", "img": "res://assets/images/badgescreen/quizwhiz-bronze.png"}, {"lvl": 2, "th": 2, "label": "2 Quizzes Completed", "img": "res://assets/images/badgescreen/quizwhiz-silver.png"}, {"lvl": 3, "th": 3, "label": "3 Quizzes Completed", "img": "res://assets/images/badgescreen/quizwhiz.png"}]},
		{"id": "boss", "name": "SWEET DEFEAT", "val": bosses, "tiers": [{"lvl": 1, "th": 1, "label": "Defeated Blue Candor", "img": "res://assets/images/badgescreen/sweetdefeat_bronze.png"}, {"lvl": 2, "th": 2, "label": "Defeated Blue Candor 2x", "img": "res://assets/images/badgescreen/sweetdefeat_silver.png"}, {"lvl": 3, "th": 4, "label": "Defeated Blue Candor 4x", "img": "res://assets/images/badgescreen/sweetdefeat_gold.png"}]},
		{"id": "coin", "name": "COIN COLLECTOR", "val": coins, "tiers": [{"lvl": 1, "th": 250, "label": "Saved 250 Coins", "img": "res://assets/images/badgescreen/coincollector_bronze.png"}, {"lvl": 2, "th": 750, "label": "Saved 750 Coins", "img": "res://assets/images/badgescreen/coincollector_silver.png"}, {"lvl": 3, "th": 2000, "label": "Saved 2000 Coins", "img": "res://assets/images/badgescreen/coincollector_gold.png"}]},
		{"id": "point", "name": "POINT MASTER", "val": pts, "tiers": [{"lvl": 1, "th": 500, "label": "Earned 500 Points", "img": "res://assets/images/badgescreen/Pointsmaster_bronze.png"}, {"lvl": 2, "th": 2000, "label": "Earned 2000 Points", "img": "res://assets/images/badgescreen/pointmaster_silver.png"}, {"lvl": 3, "th": 5000, "label": "Earned 5000 Points", "img": "res://assets/images/badgescreen/Pointsmaster_gold.png"}]},
		{"id": "sparkle", "name": "FIRST SPARKLE", "val": sparkle_cnt, "tiers": [{"lvl": 1, "th": 1, "label": "Completed First Brush", "img": "res://assets/images/badgescreen/firstsparkle.png"}]},
		{"id": "champion", "name": "PEARLY CHAMPION", "val": completed_days, "tiers": [{"lvl": 1, "th": 28, "label": "Completed All 28 Days", "img": "res://assets/images/badgescreen/pearlychampion.png"}]}
	]
	
	var seen_dict: Dictionary = p.get("seen_badge_unlocks", {})
	
	for b in badge_evals:
		var b_id = str(b["id"])
		var val = int(b["val"])
		var seen_lvl = int(seen_dict.get(b_id, 0))
		
		for t in b["tiers"]:
			var lvl = int(t["lvl"])
			var th = int(t["th"])
			if val >= th and lvl > seen_lvl:
				seen_dict[b_id] = lvl
				p["seen_badge_unlocks"] = seen_dict
				if notify:
					var ach_key = "badge_%s_%d" % [b_id, lvl]
					var already = false
					for q in p.get("queued_achievements", []):
						if q.get("id", "") == ach_key:
							already = true
							break
					if not already:
						push_achievement("Badge Unlocked!", "%s - %s" % [b["name"], t["label"]], "Trophy earned and added to your collection!", 100, "", t["img"])

func unlock_character(char_id: String, notify: bool = true) -> bool:
	var p = get_active_profile()
	if p.is_empty(): return false
	if not p.has("unlockedCharacters") or typeof(p["unlockedCharacters"]) != TYPE_ARRAY:
		p["unlockedCharacters"] = ["chip", "flora"]
	if not p.has("seen_character_unlocks") or typeof(p["seen_character_unlocks"]) != TYPE_ARRAY:
		p["seen_character_unlocks"] = ["chip", "flora"]
		
	if not p["unlockedCharacters"].has(char_id):
		p["unlockedCharacters"].append(char_id)
		
	if notify and not p["seen_character_unlocks"].has(char_id):
		var char_name = char_id.capitalize()
		for c in CHARACTERS:
			if c["id"] == char_id:
				char_name = c["name"]
				break
		push_achievement("New Champion!", "%s has joined your team!" % char_name, "Unlocked!", 50, char_id)
		push_toast("Avatar Unlocked!", "%s is now available!" % char_name, "", "green", "avatar_unlocked_" + char_id)
		save_game()
		stats_updated.emit(p)
		return true
	save_game()
	stats_updated.emit(p)
	return false

func push_achievement(heading: String, subtitle: String, body: String = "", coins: int = 0, char_id: String = "", image_path: String = "", stars: int = 0):
	var ach_id = ("ach_char_" + char_id) if char_id != "" else ("ach_" + heading + "_" + subtitle).replace(" ", "_").to_lower()
	var a = {
		"id": ach_id,
		"heading": heading,
		"subtitle": subtitle,
		"body": body,
		"coins": coins,
		"stars": stars,
		"char_id": char_id,
		"image": image_path,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var p = get_active_profile()
	if not p.is_empty():
		if not p.has("queued_achievements") or typeof(p["queued_achievements"]) != TYPE_ARRAY:
			p["queued_achievements"] = []
			
		var already_queued = false
		for existing in p["queued_achievements"]:
			if existing.get("id", "") == ach_id or (char_id != "" and existing.get("char_id", "") == char_id):
				already_queued = true
				break
		if not already_queued:
			p["queued_achievements"].append(a)
			save_game()
			
	achievement_unlocked.emit(a)

func push_toast(_title: String, _body: String = "", _icon: String = "", _tone: String = "green", _id: String = ""):
	# Top notifications disabled per user request
	pass


func complete_brushing(full_two_minutes: bool, evening: bool = false):
	var p = get_active_profile()
	if p.is_empty(): return
	
	if not full_two_minutes:
		p["cavityLevel"] = min(5, p.get("cavityLevel", 0) + 1)
		save_game()
		stats_updated.emit(p)
		return
		
	var node = int(p.get("currentNode", 1))
	var day = day_for_node(node)
	var day_idx = clamp(day - 1, 0, 27)
	if day_idx < p["daysStatus"].size():
		if evening:
			p["daysStatus"][day_idx] = "done"
		
	# Award fact for this session AND backfill any previously missed morning facts.
	# Each morning brush day D earns fact index D-1 (0-based).
	if not evening:
		for d_idx in range(day_idx + 1):
			var fi = min(FACTS.size() - 1, d_idx)
			if not p["factsCollected"].has(fi):
				p["factsCollected"].append(fi)
		# Unlock story page upon completing morning brushing session
		if not p.has("unlockedStory") or typeof(p["unlockedStory"]) != TYPE_ARRAY:
			p["unlockedStory"] = []
		if day != 28 and not p["unlockedStory"].has(day):
			p["unlockedStory"].append(day)

	p["factsRead"] = p["factsCollected"].size()
	
	var coins_gain = 100 if is_multiplier_active(p) else 50
	p["coins"] = int(round(float(p.get("coins", 0)))) + coins_gain
	p["points"] = int(round(float(p.get("points", 0)))) + 100
	p["totalMinutes"] = get_total_brushing_minutes(p) + 2
	p["totalBrushingSeconds"] = p["totalMinutes"] * 60
	p["brushing_time"] = p["totalMinutes"] * 60
	p["cavityLevel"] = 0
	
	var today_str = Time.get_date_string_from_system()
	p["lastBrushDate"] = today_str
	if evening:
		p["lastEveningBrushDate"] = today_str

	if not evening:
		set_node_stage(node, 1)

	check_character_unlocks(p, true)
	check_level_up(p)
	save_game()
	stats_updated.emit(p)

func finish_node(evening: bool = false):
	var p = get_active_profile()
	if p.is_empty(): return
	var node = int(p.get("currentNode", 0))
	if not p.has("nodeStage") or typeof(p["nodeStage"]) != TYPE_DICTIONARY:
		p["nodeStage"] = {}
	p["nodeStage"][str(node)] = 99
	p["currentNode"] = node + 1

	var n_info = get_node_data(node)
	var is_ev = evening or (n_info.get("type", "") == "evening")
	var day = n_info.get("day", 1)
	var today_str = Time.get_date_string_from_system()
	p["lastBrushDate"] = today_str
	if is_ev:
		var day_idx = clamp(day - 1, 0, 27)
		if p.has("daysStatus"):
			# FIX: Mark skipped morning/evening as missed if applicable
			if day_idx < p["daysStatus"].size() and p["daysStatus"][day_idx] == "todo":
				p["daysStatus"][day_idx] = "missed"
			elif day_idx < p["daysStatus"].size():
				p["daysStatus"][day_idx] = "done"
		p["lastEveningBrushDate"] = today_str
		p["streak"] = int(p.get("streak", 0)) + 1
	check_character_unlocks(p, true)
	save_game()
	stats_updated.emit(p)

func get_node_stage(node_id: int) -> int:
	var p = get_active_profile()
	if p.is_empty(): return 0
	var stages = p.get("nodeStage", {})
	return int(stages.get(str(int(node_id)), 0))

func set_node_stage(node_id: int, stage: int):
	var p = get_active_profile()
	if p.is_empty(): return
	if not p.has("nodeStage") or typeof(p["nodeStage"]) != TYPE_DICTIONARY:
		p["nodeStage"] = {}
	p["nodeStage"][str(int(node_id))] = stage
	save_game()
	stats_updated.emit(p)

func record_brushing_completed(total_secs: int = 120):
	var p = get_active_profile()
	if p.is_empty(): return
	var cur_node: int = int(p.get("currentNode", 1))
	var n_data = get_node_data(cur_node)
	var is_evening: bool = (n_data.get("type", "") == "evening")
	var required_secs = 20 if dev_mode else 120
	complete_brushing(total_secs >= required_secs, is_evening)
	if is_evening and int(n_data.get("day", 0)) == 28:
		set_node_stage(cur_node, 1) # Day 28: Candy Crusade still to play after the night brush
	elif is_evening:
		finish_node(true)
	else:
		set_node_stage(cur_node, 1)

func complete_quiz(correct: int, total: int):
	var p = get_active_profile()
	if p.is_empty(): return
	var points = correct * 10
	p["points"] = p.get("points", 0) + points
	p["quizzesCompleted"] = p.get("quizzesCompleted", 0) + 1
	if correct == total:
		p["quizPerfect"] = true
	check_character_unlocks(p, true)
	check_level_up(p)
	save_game()
	stats_updated.emit(p)

func add_minion_kills(kills: int, points_gained: int, boss_defeated: bool = false):
	var p = get_active_profile()
	if p.is_empty(): return
	p["minionsDefeated"] = p.get("minionsDefeated", 0) + kills
	p["points"] = p.get("points", 0) + points_gained
	if boss_defeated:
		p["bossesDefeated"] = p.get("bossesDefeated", 0) + 1
	check_character_unlocks(p, true)
	check_level_up(p)
	save_game()
	stats_updated.emit(p)

func buy_power_up(id: String, qty: int = 1) -> bool:
	var p = get_active_profile()
	if p.is_empty(): return false
	var pu = null
	for item in POWER_UPS:
		if item["id"] == id:
			pu = item
			break
	if not pu: return false
	var total_cost = int(round(float(pu["cost"]))) * qty
	if pu["currency"] == "coins":
		if int(round(float(p.get("coins", 0)))) < total_cost: return false
		p["coins"] = int(round(float(p.get("coins", 0)))) - total_cost
	else:
		if int(round(float(p.get("points", 0)))) < total_cost: return false
		p["points"] = int(round(float(p.get("points", 0)))) - total_cost
		
	if id == "shield":
		p["inventory"]["shield"] = int(round(float(p["inventory"].get("shield", 0)))) + qty
	elif id == "freeze":
		p["inventory"]["freeze"] = int(round(float(p["inventory"].get("freeze", 0)))) + qty
		p["lastFreezePurchase"] = Time.get_unix_time_from_system()
	elif id == "multiplier":
		p["multiplierActiveUntil"] = Time.get_unix_time_from_system() + qty * 86400.0
	elif id == "exchange":
		p["points"] = int(round(float(p.get("points", 0)))) + 100 * qty
		
	push_toast("Purchased!", pu["name"], "", "green")
	_sanitize_profile(p)
	save_game()
	stats_updated.emit(p)
	return true

func buy_accessory(id: String) -> bool:
	var p = get_active_profile()
	if p.is_empty(): return false
	var acc = null
	for a in ACCESSORIES:
		if a["id"] == id:
			acc = a
			break
	if not acc: return false
	if p["ownedAccessories"].has(id): return false
	var cost = int(round(float(acc["cost"])))
	if int(round(float(p.get("coins", 0)))) < cost: return false
	p["coins"] = int(round(float(p.get("coins", 0)))) - cost
	p["ownedAccessories"].append(id)
	push_toast("Accessory Unlocked!", acc["name"], "", "green")
	_sanitize_profile(p)
	save_game()
	stats_updated.emit(p)
	return true

func equip_accessory(id: String):
	var p = get_active_profile()
	if p.is_empty(): return
	p["equippedAccessory"] = id
	save_game()
	stats_updated.emit(p)

func clear_cavities():
	var p = get_active_profile()
	if p.is_empty(): return
	p["cavityLevel"] = 0
	save_game()
	stats_updated.emit(p)

func apply_gift(gift: String):
	var p = get_active_profile()
	if p.is_empty(): return
	if gift == "+500 Coins" or gift == "+250 Coins":
		var c_gain = 250 if gift == "+250 Coins" else 500
		p["coins"] = p.get("coins", 0) + c_gain
	elif gift == "+200 Points" or gift == "+250 Points" or gift == "+100 Points" or gift == "+1000 Points":
		var pt_gain = 200
		if gift == "+250 Points": pt_gain = 250
		elif gift == "+100 Points": pt_gain = 100
		elif gift == "+1000 Points": pt_gain = 250 # Cap legacy 1000 points to 250
		p["points"] = p.get("points", 0) + pt_gain
	elif gift == "Streak Freeze":
		p["inventory"]["freeze"] = p["inventory"].get("freeze", 0) + 1
	elif gift == "Fluoride Shield":
		p["inventory"]["shield"] = p["inventory"].get("shield", 0) + 1
	save_game()
	stats_updated.emit(p)

func get_current_profile() -> Dictionary:
	var p = get_active_profile()
	if not p.has("avatar_id") and p.has("avatar"):
		p["avatar_id"] = p["avatar"]
	if not p.has("brushing_time"):
		p["brushing_time"] = get_total_brushing_minutes(p) * 60
	return p

func get_total_brushing_minutes(p: Dictionary = {}) -> int:
	if p.is_empty():
		p = get_active_profile()
	if p.is_empty():
		return 0
		
	var mins = int(round(float(p.get("totalMinutes", 0))))
	if mins <= 0:
		var secs = int(round(float(p.get("totalBrushingSeconds", p.get("brushing_time", 0)))))
		mins = secs / 60
		
	if mins <= 0:
		var streak = int(round(float(p.get("streak", 0))))
		var cur_node = int(round(float(p.get("currentNode", 1))))
		var completed_nodes = max(0, cur_node - 1)
		var estimated_sessions = max(completed_nodes, streak * 2)
		mins = estimated_sessions * 2

	return mins

# ------------------------------------------------------------------
# Candy Crusade background preloading
# Started once at app launch (main.gd). Everything Candy Crusade needs is loaded
# on background threads and KEPT in memory, then rendered once off-screen so the
# graphics shaders are compiled. Opening Candy Crusade afterwards is instant.
# ------------------------------------------------------------------
signal candy_crusade_ready

const CANDY_MAIN_SCENE := "res://candy_crusade/main.tscn"
const CANDY_PRELOAD_PATHS := [
	"res://candy_crusade/minion.tscn",
	"res://candy_crusade/blue_candor.tscn",
	"res://candy_crusade/boss_candy.tscn",
	"res://candy_crusade/projectile.tscn",
	"res://candy_crusade/boomerang.tscn",
	"res://candy_crusade/grenade.tscn",
	"res://candy_crusade/molar_coin.tscn",
	"res://candy_crusade/ammo_crate.tscn",
	"res://assets/candy_crusade/models/AmmoChestClosed.glb",
	"res://assets/candy_crusade/models/AmmoChestOpen.glb",
	"res://assets/candy_crusade/models/blue_candor.glb",
	"res://assets/candy_crusade/models/blue_minion.glb",
	"res://assets/candy_crusade/models/BlueCandorHit.glb",
	"res://assets/candy_crusade/models/BonbonMinionHit.glb",
	"res://assets/candy_crusade/models/brush_boomerang.glb",
	"res://assets/candy_crusade/models/BubbleBrush.glb",
	"res://assets/candy_crusade/models/Goldbrushlvl2.glb",
	"res://assets/candy_crusade/models/level1pistolbullet.glb",
	"res://assets/candy_crusade/models/level2pistolbullet.glb",
	"res://assets/candy_crusade/models/level3pistolbullet.glb",
	"res://assets/candy_crusade/models/Level2BrushBattery.glb",
	"res://assets/candy_crusade/models/Level3BrushBattery.glb",
	"res://assets/candy_crusade/models/molarcoin.glb",
	"res://assets/candy_crusade/models/mouthwash_blast.glb",
	"res://assets/candy_crusade/models/MWashBubble3.glb",
	"res://assets/candy_crusade/models/MWashGold2.glb",
	"res://assets/candy_crusade/models/PasteBubble3.glb",
	"res://assets/candy_crusade/models/PasteGold2.glb",
	"res://assets/candy_crusade/models/toothpaste_pistol.glb",
]

var is_candy_crusade_preloading: bool = false
var candy_crusade_scene: PackedScene = null
var _candy_preload_cache: Array = []   # keeps loaded models in memory (Godot frees unreferenced resources)
var _candy_warmed_up: bool = false
var _candy_in_use: bool = false

func is_candy_crusade_ready() -> bool:
	return candy_crusade_scene != null

func preload_candy_crusade_in_background() -> void:
	if is_candy_crusade_preloading or candy_crusade_scene != null:
		return
	is_candy_crusade_preloading = true
	var paths: Array = [CANDY_MAIN_SCENE]
	paths.append_array(CANDY_PRELOAD_PATHS)
	var pending: Array = []
	for p in paths:
		if not ResourceLoader.exists(p):
			continue
		var st := ResourceLoader.load_threaded_get_status(p)
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS and st != ResourceLoader.THREAD_LOAD_LOADED:
			# sub-threads only for the big main scene, so the phone stays responsive
			if ResourceLoader.load_threaded_request(p, "", p == CANDY_MAIN_SCENE) != OK:
				continue
		pending.append(p)
	_collect_candy_preload(pending)

func _collect_candy_preload(pending: Array) -> void:
	while not pending.is_empty():
		await get_tree().process_frame
		var still: Array = []
		for p in pending:
			var st := ResourceLoader.load_threaded_get_status(p)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				still.append(p)
			elif st == ResourceLoader.THREAD_LOAD_LOADED:
				var res := ResourceLoader.load_threaded_get(p)
				if p == CANDY_MAIN_SCENE:
					candy_crusade_scene = res as PackedScene
				elif res:
					_candy_preload_cache.append(res)
		pending = still
	if candy_crusade_scene == null and ResourceLoader.exists(CANDY_MAIN_SCENE):
		candy_crusade_scene = load(CANDY_MAIN_SCENE) as PackedScene
	is_candy_crusade_preloading = false
	candy_crusade_ready.emit()
	if candy_crusade_scene == null:
		push_error("Candy Crusade preload failed: " + CANDY_MAIN_SCENE)
		return
	_warm_up_candy_crusade()

## Returns the preloaded Candy Crusade scene, waiting for the background load if it's still running.
# FIX: Proper loading with validation and fallback
func get_candy_crusade_scene() -> PackedScene:
	if candy_crusade_scene == null:
		preload_candy_crusade_in_background()
		if is_candy_crusade_preloading:
			var start_time = Time.get_ticks_msec()
			var timeout_ms = 25000  # 25 seconds - increased from 20s
			while is_candy_crusade_preloading and (Time.get_ticks_msec() - start_time) < timeout_ms:
				await get_tree().process_frame

			# If timeout occurred and scene still null, fallback to blocking load
			if candy_crusade_scene == null:
				push_warning("Candy Crusade preload timeout - falling back to blocking load")
				candy_crusade_scene = load(CANDY_MAIN_SCENE) as PackedScene

	# Wait for warm-up to complete if it's running
	if candy_crusade_scene != null and _candy_warmed_up == false and _candy_in_use == false:
		# Give warm-up a chance to start and complete
		var warm_timeout = Time.get_ticks_msec()
		while _candy_warmed_up == false and (Time.get_ticks_msec() - warm_timeout) < 10000:
			if _candy_in_use:
				break
			await get_tree().process_frame

	return candy_crusade_scene

# Renders the Candy Crusade world once in an invisible viewport (scripts removed, so
# no gameplay, sound or UI runs). This compiles every material's shader up front,
# which is what normally causes the long freeze the first time the arena opens.
func _warm_up_candy_crusade() -> void:
	if _candy_warmed_up or candy_crusade_scene == null or _candy_in_use:
		return

	# FIX: Validate scene can be instantiated before warming up
	var world = candy_crusade_scene.instantiate()
	if world == null:
		push_error("Candy Crusade instantiation failed - scene is null")
		_candy_warmed_up = true
		return

	_strip_for_warmup(world)

	var vp := SubViewport.new()
	vp.name = "CandyCrusadeWarmup"
	vp.size = Vector2i(180, 320)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_DISABLED

	vp.add_child(world)
	get_tree().root.add_child(vp)

	var cam := world.find_child("Camera3D", true, false) as Camera3D
	var cam_xf := cam.global_transform if cam else Transform3D.IDENTITY
	var i := 0
	for res in _candy_preload_cache:
		if res is PackedScene:
			var inst := (res as PackedScene).instantiate()
			if inst == null:
				push_warning("Failed to instantiate cached Candy Crusade resource")
				continue
			_strip_for_warmup(inst)
			world.add_child(inst)
			if inst is Node3D:
				var local := Vector3(float(i % 4) - 1.5, -0.3 + floorf(float(i) / 4.0) * 0.3, -4.0)
				(inst as Node3D).global_position = cam_xf * local
			i += 1

	# FIX: Give more frames for shaders to compile
	for _f in range(8):
		await get_tree().process_frame

	vp.queue_free()
	_candy_warmed_up = true
	print("Candy Crusade warm-up completed successfully")

func _strip_for_warmup(n: Node) -> void:
	n.set_script(null)
	if n is Node3D:
		(n as Node3D).visible = true
	elif n is CanvasLayer:
		(n as CanvasLayer).visible = false
	if n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D:
		n.set("autoplay", false)
	for c in n.get_children():
		_strip_for_warmup(c)

func add_points(amount: int):
	var p = get_active_profile()
	if p.is_empty(): return
	p["points"] = int(round(float(p.get("points", 0)))) + int(round(float(amount)))
	_sanitize_profile(p)
	check_character_unlocks(p, true)
	check_level_up(p)
	save_game()
	stats_updated.emit(p)

func add_molar_coins(amount: int):
	var p = get_active_profile()
	if p.is_empty(): return
	p["coins"] = int(round(float(p.get("coins", 0)))) + int(round(float(amount)))
	_sanitize_profile(p)
	save_game()
	stats_updated.emit(p)

func add_coins(amount: int):
	add_molar_coins(amount)

func increment_stat(stat_name: String, amount: int = 1):
	var p = get_active_profile()
	if p.is_empty(): return
	var key := stat_name
	if key == "minions_defeated": key = "minionsDefeated"
	elif key == "bosses_defeated": key = "bossesDefeated"
	elif key == "facts_read": key = "factsRead"
	p[key] = int(round(float(p.get(key, 0)))) + amount
	_sanitize_profile(p)
	check_character_unlocks(p, true)
	save_game()
	stats_updated.emit(p)

# Canonical map node sequence helpers (2 brushing nodes per day, plus mini-game and quiz nodes)
static func get_morning_node_for_day(target_day: int) -> int:
	var node_id = 1
	for d in range(1, 29):
		if d == target_day:
			return node_id
		node_id += 2 # morning + evening
		if BONUS_MINIGAME_DAYS.has(d):
			node_id += 1 # minigame
		if BONUS_QUIZ_DAYS.has(d):
			node_id += 1 # quiz
	return node_id

func is_day_morning_brush_done(day_num: int, p: Dictionary = {}) -> bool:
	if day_num < 1 or day_num > 28:
		return false
	var profile = p
	if profile.is_empty():
		profile = get_active_profile()
	if profile.is_empty():
		return false
	var cur_node = int(profile.get("currentNode", 1))
	var morning_node = get_morning_node_for_day(day_num)
	if cur_node > morning_node:
		return true
	var stages = profile.get("nodeStage", {})
	if typeof(stages) == TYPE_DICTIONARY and int(stages.get(str(morning_node), 0)) >= 1:
		return true
	return false

func is_day_morning_completed(day_num: int, p: Dictionary = {}) -> bool:
	if day_num < 1 or day_num > 28:
		return false
	var profile = p
	if profile.is_empty():
		profile = get_active_profile()
	if profile.is_empty():
		return false
	var cur_node = int(profile.get("currentNode", 1))
	var morning_node = get_morning_node_for_day(day_num)
	if cur_node > morning_node:
		return true
	var stages = profile.get("nodeStage", {})
	if typeof(stages) == TYPE_DICTIONARY and int(stages.get(str(morning_node), 0)) >= 99:
		return true
	return false

static func get_evening_node_for_day(target_day: int) -> int:
	# Day 28 has the Final Quiz between the morning and evening brushes
	var extra: int = 1 if target_day == FINAL_QUIZ_DAY else 0
	return get_morning_node_for_day(target_day) + 1 + extra

func is_day_evening_completed(day_num: int, p: Dictionary = {}) -> bool:
	if day_num < 1 or day_num > 28:
		return false
	var profile = p
	if profile.is_empty():
		profile = get_active_profile()
	if profile.is_empty():
		return false
	var cur_node = int(profile.get("currentNode", 1))
	var evening_node = get_evening_node_for_day(day_num)
	if cur_node > evening_node:
		return true
	var stages = profile.get("nodeStage", {})
	if typeof(stages) == TYPE_DICTIONARY and int(stages.get(str(evening_node), 0)) >= 99:
		return true
	var day_idx = day_num - 1
	var days_status = profile.get("daysStatus", [])
	if typeof(days_status) == TYPE_ARRAY and day_idx < days_status.size():
		if str(days_status[day_idx]) == "done":
			return true
	return false

func is_day_story_unlocked(day_num: int, p: Dictionary = {}) -> bool:
	if day_num < 1 or day_num > 28:
		return false
	var profile = p
	if profile.is_empty():
		profile = get_active_profile()
	if profile.is_empty():
		return false
	# Day 28's story panel opens right after the evening brush + Candy Crusade are completed
	# (the FINISH node then only shows the Pearly Champion trophy and confetti)
	if day_num == 28:
		return is_day_evening_completed(28, profile)
	var unlocked_story = profile.get("unlockedStory", [])
	if typeof(unlocked_story) == TYPE_ARRAY and unlocked_story.has(day_num):
		return true
	var cur_node = int(profile.get("currentNode", 1))
	var cur_day = day_for_node(cur_node)
	if day_num < cur_day:
		return true
	if day_num > cur_day:
		return false
	return is_day_morning_completed(day_num, profile)

func get_unlocked_story_count(p: Dictionary = {}) -> int:
	var profile = p
	if profile.is_empty():
		profile = get_active_profile()
	var count = 0
	for d in range(1, 29):
		if is_day_story_unlocked(d, profile):
			count += 1
	return count

func get_progress_dict() -> Dictionary:
	var p = get_active_profile()
	var cur_node = int(p.get("currentNode", 1))
	var cur_day = day_for_node(cur_node)
	return {
		"current_day": cur_day,
		"current_node": cur_node,
		"streak": int(p.get("streak", 0)),
		"coins": int(p.get("coins", 0)),
		"points": int(p.get("points", 0)),
		"ammo": p.get("ammo", {"brushes": 40, "paste": 15, "wash": 10, "floss": 5}),
		"weaponLevels": p.get("weaponLevels", {}),
		"weaponTiers": p.get("weaponTiers", {}),
		"daysStatus": p.get("daysStatus", []),
		"unlockedCharacters": p.get("unlockedCharacters", ["chip", "flora"]),
		"unlockedStory": p.get("unlockedStory", []),
		"factsRead": int(p.get("factsRead", 0)),
		"quizzesCompleted": int(p.get("quizzesCompleted", 0)),
		"active_character": p.get("character", "chip")
	}

func populate_from_progress_dict(dict: Dictionary, source_user_id: String = ""):
	if dict.is_empty():
		return
	var p = get_active_profile()
	if p.is_empty():
		return
	var target_user_id = source_user_id if source_user_id != "" else str(dict.get("active_id", dict.get("user_id", "")))
	if target_user_id != "" and p.get("id", "") != "" and target_user_id != p.get("id", ""):
		# Data is from a different user profile — strictly prevent data bleed!
		return
	if dict.has("streak"):
		p["streak"] = max(int(p.get("streak", 0)), int(dict["streak"]))
	if dict.has("points"):
		p["points"] = max(int(p.get("points", 0)), int(dict["points"]))
	if dict.has("ammo") and typeof(dict["ammo"]) == TYPE_DICTIONARY:
		var loc_ammo = p.get("ammo", {})
		if typeof(loc_ammo) == TYPE_DICTIONARY:
			for ak in dict["ammo"]:
				loc_ammo[ak] = max(int(loc_ammo.get(ak, 0)), int(dict["ammo"][ak]))
			p["ammo"] = loc_ammo
		else:
			p["ammo"] = dict["ammo"]
	if dict.has("weaponTiers") and typeof(dict["weaponTiers"]) == TYPE_DICTIONARY:
		var loc_tiers = p.get("weaponTiers", {})
		if typeof(loc_tiers) != TYPE_DICTIONARY:
			loc_tiers = {"brush": [1], "paste": [], "wash": [], "floss": []}
		var inc_tiers = dict["weaponTiers"]
		for wk in ["brush", "paste", "wash", "floss"]:
			var lt = loc_tiers.get(wk, []) if typeof(loc_tiers.get(wk, [])) == TYPE_ARRAY else []
			var it = inc_tiers.get(wk, []) if typeof(inc_tiers.get(wk, [])) == TYPE_ARRAY else []
			var merged: Array = []
			for t in lt:
				var ti = int(round(float(t)))
				if ti >= 1 and ti <= 3 and not merged.has(ti): merged.append(ti)
			for t in it:
				var ti = int(round(float(t)))
				if ti >= 1 and ti <= 3 and not merged.has(ti): merged.append(ti)
			merged.sort()
			loc_tiers[wk] = merged
		p["weaponTiers"] = loc_tiers
	if dict.has("weaponLevels") and typeof(dict["weaponLevels"]) == TYPE_DICTIONARY:
		var loc_levels = p.get("weaponLevels", {})
		if typeof(loc_levels) != TYPE_DICTIONARY:
			loc_levels = {"brush": 1, "paste": 0, "wash": 0, "floss": 0}
		for wk in ["brush", "paste", "wash", "floss"]:
			var tiers: Array = p.get("weaponTiers", {}).get(wk, [])
			var max_lvl = 1 if wk == "brush" else 0
			for t in tiers:
				max_lvl = max(max_lvl, int(t))
			loc_levels[wk] = max_lvl
		p["weaponLevels"] = loc_levels
	if dict.has("daysStatus") and typeof(dict["daysStatus"]) == TYPE_ARRAY:
		p["daysStatus"] = dict["daysStatus"]
	if dict.has("current_node"):
		var inc_node = int(dict["current_node"])
		p["currentNode"] = max(int(p.get("currentNode", 0)), inc_node)
	_sanitize_profile(p)
	
	var save_dict = {
		"profiles": profiles,
		"active_id": active_id,
		"family_mode": family_mode,
		"family_competition_winner": family_competition_winner,
		"family_code": family_code,
		"tooth_fairy_pin": tooth_fairy_pin
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "  "))
		file.flush()
		file.close()
		
	stats_updated.emit(p)

