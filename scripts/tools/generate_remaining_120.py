import json
import random

def generate_procedural():
    scenarios = []
    
    # ------------------ FIRE TEMPLATES ------------------
    fire_bases = [
        {
            "id": "gen_fire_template_0", "title": "Kitchen Stove Fire",
            "en_text": "The stove caught on fire and the flames are hitting the ceiling!",
            "tl_text": "Nasusunog ang kalan at umaabot na sa kisame ang apoy!",
            "taglish_text": "Nag-catch fire yung stove at nasa ceiling na ang flames!",
            "safe_en": "Evacuate the house immediately and stay outside.", "safe_tl": "Lumabas agad ng bahay at manatili sa labas.", "safe_taglish": "Mag-evacuate agad sa house at mag-stay sa labas.",
            "safe_k_en": ["evacuate", "outside", "safe"], "safe_k_tl": ["lumabas", "labas", "ligtas"], "safe_k_taglish": ["evacuate", "labas", "safe"],
            "unsafe_en": ["Throw water on it.", "Try to beat it with a towel.", "Open the windows.", "Run inside to grab your things.", "Turn on the fan."],
            "unsafe_tl": ["Buhusan ng tubig.", "Hampasin ng tuwalya.", "Buksan ang mga bintana.", "Pumasok para kunin ang gamit.", "Buksan ang bentilador."],
            "unsafe_taglish": ["Buhusan ng water.", "Hampasin ng towel.", "I-open ang windows.", "Pumasok para kunin ang things.", "I-turn on ang fan."],
            "unsafe_k_en": ["water", "towel", "windows", "inside", "fan"], "unsafe_k_tl": ["tubig", "tuwalya", "bintana", "loob", "bentilador"], "unsafe_k_taglish": ["water", "towel", "windows", "loob", "fan"]
        },
        {
            "id": "gen_fire_template_1", "title": "Electrical Fire",
            "en_text": "Sparks are flying from the wall outlet and the curtains are burning!",
            "tl_text": "Lumalabas ang kislap sa outlet at nasusunog ang kurtina!",
            "taglish_text": "May sparks sa outlet at nagbe-burn na ang curtains!",
            "safe_en": "Get out of the house and do not use water.", "safe_tl": "Lumabas ng bahay at huwag gagamit ng tubig.", "safe_taglish": "Get out of the house at wag gagamit ng tubig.",
            "safe_k_en": ["out", "do not use water", "leave"], "safe_k_tl": ["lumabas", "wag tubig", "alis"], "safe_k_taglish": ["out", "wag water", "leave"],
            "unsafe_en": ["Throw a bucket of water on the outlet.", "Try to pull the wires out.", "Hit the wall with a hammer.", "Hide under the bed.", "Wait for it to stop."],
            "unsafe_tl": ["Sabuyan ng tubig ang outlet.", "Subukang hugutin ang mga wire.", "Paluin ang pader ng martilyo.", "Magtago sa ilalim ng kama.", "Hintaying tumigil."],
            "unsafe_taglish": ["Sabuyan ng water ang outlet.", "I-pull ang wires.", "Paluin ng hammer ang wall.", "Mag-hide sa bed.", "Mag-wait mag-stop."],
            "unsafe_k_en": ["water", "pull", "hammer", "hide", "wait"], "unsafe_k_tl": ["tubig", "hugot", "martilyo", "tago", "hintay"], "unsafe_k_taglish": ["water", "pull", "hammer", "hide", "wait"]
        },
        {
            "id": "gen_fire_template_2", "title": "Trash Can Fire",
            "en_text": "Someone threw a cigarette in the trash bin and it's engulfed in flames!",
            "tl_text": "May nagtapon ng sigarilyo sa basurahan at nasusunog na ito!",
            "taglish_text": "May nag-throw ng cigarette sa basurahan at engulfed in flames na!",
            "safe_en": "Move away from the fire and do not attempt to extinguish it yourself.", "safe_tl": "Lumayo sa apoy at huwag subukang patayin ito nang mag-isa.", "safe_taglish": "Move away sa fire at wag i-try patayin mag-isa.",
            "safe_k_en": ["move away", "leave", "safe distance"], "safe_k_tl": ["lumayo", "alis", "ligtas"], "safe_k_taglish": ["move away", "leave", "safe"],
            "unsafe_en": ["Kick the trash can over.", "Pour cooking oil on it.", "Throw paper into the fire.", "Try to pick it up.", "Ignore it completely."],
            "unsafe_tl": ["Sipain ang basurahan.", "Buhusan ng mantika.", "Magtapon ng papel sa apoy.", "Subukang buhatin ito.", "Ibalewala na lang."],
            "unsafe_taglish": ["I-kick ang basurahan.", "Buhusan ng cooking oil.", "Mag-throw ng paper sa fire.", "I-pick up ito.", "I-ignore na lang."],
            "unsafe_k_en": ["kick", "oil", "paper", "pick up", "ignore"], "unsafe_k_tl": ["sipa", "mantika", "papel", "buhat", "balewala"], "unsafe_k_taglish": ["kick", "oil", "paper", "pick up", "ignore"]
        },
        {
            "id": "gen_fire_template_3", "title": "Car Engine Fire",
            "en_text": "Smoke is pouring out of my car engine on the highway!",
            "tl_text": "Umuusok ang makina ng kotse ko dito sa highway!",
            "taglish_text": "May smoke na lumalabas sa engine ng car ko sa highway!",
            "safe_en": "Evacuate the vehicle and stand behind the guardrail.", "safe_tl": "Bumaba sa sasakyan at tumayo sa likod ng guardrail.", "safe_taglish": "Mag-evacuate sa car at mag-stand sa likod ng guardrail.",
            "safe_k_en": ["evacuate", "stand behind", "guardrail"], "safe_k_tl": ["bumaba", "tumayo", "guardrail"], "safe_k_taglish": ["evacuate", "stand", "guardrail"],
            "unsafe_en": ["Open the hood to check.", "Get back inside for your bag.", "Try to blow the fire out.", "Pour your drink on it.", "Stand in front of the car."],
            "unsafe_tl": ["Buksan ang hood para silipin.", "Bumalik sa loob para kunin ang bag.", "Subukang hipan ang apoy.", "Ibuhos ang inumin mo dito.", "Tumayo sa harap ng kotse."],
            "unsafe_taglish": ["I-open ang hood.", "Bumalik sa loob para sa bag.", "I-blow ang fire.", "I-pour ang drink.", "Mag-stand sa harap."],
            "unsafe_k_en": ["hood", "inside", "blow", "drink", "front"], "unsafe_k_tl": ["hood", "loob", "hipan", "inumin", "harap"], "unsafe_k_taglish": ["hood", "loob", "blow", "drink", "harap"]
        }
    ]

    # ------------------ POLICE TEMPLATES ------------------
    police_bases = [
        {
            "id": "gen_pol_template_0", "title": "Burglary in Progress",
            "en_text": "Someone is breaking through my back door! I'm hiding upstairs!",
            "tl_text": "May sumisira sa pinto ko sa likod! Nagtatago ako sa itaas!",
            "taglish_text": "May nagbe-break sa back door ko! Nagha-hide ako sa taas!",
            "safe_en": "Stay quiet, lock your door, and remain on the line.", "safe_tl": "Manatiling tahimik, i-lock ang pinto, at huwag ibababa ang linya.", "safe_taglish": "Stay quiet, i-lock ang door, at wag i-drop ang line.",
            "safe_k_en": ["quiet", "lock", "stay"], "safe_k_tl": ["tahimik", "lock", "manatili"], "safe_k_taglish": ["quiet", "lock", "stay"],
            "unsafe_en": ["Yell at them.", "Run downstairs.", "Turn on the lights.", "Throw something out the window.", "Hang up the phone."],
            "unsafe_tl": ["Sigawan sila.", "Tumakbo pababa.", "Buksan ang mga ilaw.", "Magtapon ng gamit sa bintana.", "Ibaba ang telepono."],
            "unsafe_taglish": ["I-yell sila.", "Mag-run downstairs.", "I-turn on ang lights.", "Mag-throw sa window.", "I-hang up ang phone."],
            "unsafe_k_en": ["yell", "run", "lights", "throw", "hang up"], "unsafe_k_tl": ["sigaw", "takbo", "ilaw", "tapon", "ibaba"], "unsafe_k_taglish": ["yell", "run", "lights", "throw", "hang up"]
        },
        {
            "id": "gen_pol_template_1", "title": "Domestic Violence",
            "en_text": "My neighbors are screaming and throwing furniture at each other!",
            "tl_text": "Nagsisigawan at nagbabatuhan ng gamit ang mga kapitbahay ko!",
            "taglish_text": "Screaming at nagba-bato ng furniture ang neighbors ko!",
            "safe_en": "Stay inside your home and do not intervene.", "safe_tl": "Manatili sa loob ng bahay at huwag makialam.", "safe_taglish": "Stay inside sa house at wag mag-intervene.",
            "safe_k_en": ["stay inside", "do not intervene", "safe"], "safe_k_tl": ["loob", "wag makialam", "ligtas"], "safe_k_taglish": ["stay inside", "wag makialam", "safe"],
            "unsafe_en": ["Go knock on their door.", "Yell at them to stop.", "Try to break up the fight.", "Record them with flash.", "Throw a rock at their house."],
            "unsafe_tl": ["Kumatok sa pinto nila.", "Sigawan silang tumigil.", "Subukang awatin sila.", "Kunan ng video na may flash.", "Batuhin ang bahay nila."],
            "unsafe_taglish": ["I-knock ang door nila.", "I-yell na mag-stop.", "I-try awatin ang fight.", "I-record with flash.", "Batuhin ang house nila."],
            "unsafe_k_en": ["knock", "yell", "break up", "record", "rock"], "unsafe_k_tl": ["katok", "sigaw", "awat", "video", "bato"], "unsafe_k_taglish": ["knock", "yell", "awat", "record", "rock"]
        },
        {
            "id": "gen_pol_template_2", "title": "Stolen Vehicle",
            "en_text": "Someone just hotwired my car and is driving away!",
            "tl_text": "May nagnakaw ng kotse ko at papalayo na siya!",
            "taglish_text": "May nag-hotwire ng car ko at nagda-drive away na!",
            "safe_en": "Do not chase them, just get a description of the car.", "safe_tl": "Huwag silang habulin, kunin lang ang paglalarawan ng kotse.", "safe_taglish": "Wag i-chase, kunin lang ang description ng car.",
            "safe_k_en": ["do not chase", "description", "safe"], "safe_k_tl": ["wag habulin", "ilarawan", "ligtas"], "safe_k_taglish": ["wag chase", "description", "safe"],
            "unsafe_en": ["Chase them on foot.", "Get in another car and follow them.", "Shoot at the tires.", "Throw a brick at them.", "Run out in front of the car."],
            "unsafe_tl": ["Habulin sila nang patakbo.", "Sumakay sa ibang kotse at sundan sila.", "Barilin ang mga gulong.", "Batuhin sila ng brick.", "Tumakbo sa harap ng kotse."],
            "unsafe_taglish": ["I-chase sila on foot.", "Sundan sila sa ibang car.", "I-shoot ang tires.", "Batuhin ng brick.", "Mag-run sa harap ng car."],
            "unsafe_k_en": ["chase", "follow", "shoot", "brick", "run"], "unsafe_k_tl": ["habol", "sundan", "baril", "brick", "takbo"], "unsafe_k_taglish": ["chase", "sundan", "shoot", "brick", "run"]
        },
        {
            "id": "gen_pol_template_3", "title": "Suspicious Person",
            "en_text": "There's a man looking into car windows with a flashlight.",
            "tl_text": "May lalaking sumisilip sa mga bintana ng kotse gamit ang flashlight.",
            "taglish_text": "May man na naglu-look sa car windows with flashlight.",
            "safe_en": "Observe from a distance and do not approach him.", "safe_tl": "Magmasid mula sa malayo at huwag siyang lapitan.", "safe_taglish": "Mag-observe mula sa malayo at wag i-approach.",
            "safe_k_en": ["observe", "distance", "do not approach"], "safe_k_tl": ["masid", "layo", "wag lapitan"], "safe_k_taglish": ["observe", "distance", "wag lapitan"],
            "unsafe_en": ["Go confront him.", "Yell out the window.", "Shine a laser pointer at him.", "Chase him away with a bat.", "Go outside to check your car."],
            "unsafe_tl": ["Komprontahin siya.", "Sumigaw mula sa bintana.", "Tapatan siya ng laser pointer.", "Habulin siya ng bat.", "Lumabas para silipin ang kotse mo."],
            "unsafe_taglish": ["I-confront siya.", "I-yell sa window.", "I-shine ang laser pointer.", "I-chase ng bat.", "Lumabas para i-check ang car."],
            "unsafe_k_en": ["confront", "yell", "laser", "chase", "outside"], "unsafe_k_tl": ["kompronta", "sigaw", "laser", "habol", "labas"], "unsafe_k_taglish": ["confront", "yell", "laser", "chase", "labas"]
        }
    ]

    # ------------------ MEDICAL TEMPLATES ------------------
    med_bases = [
        {
            "id": "gen_med_template_0", "title": "Heart Attack Symptoms",
            "en_text": "My father is having severe chest pain and can barely breathe!",
            "tl_text": "Sobrang sakit ng dibdib ng tatay ko at hirap siyang huminga!",
            "taglish_text": "May severe chest pain ang dad ko at hirap mag-breathe!",
            "safe_en": "Keep him seated, calm, and have him chew an aspirin if possible.", "safe_tl": "Paupuin siya, pakalmahin, at panguyaing ng aspirin kung pwede.", "safe_taglish": "Paupuin, i-calm down, at pa-chew ng aspirin.",
            "safe_k_en": ["seated", "calm", "aspirin"], "safe_k_tl": ["upo", "kalma", "aspirin"], "safe_k_taglish": ["upo", "calm", "aspirin"],
            "unsafe_en": ["Make him do pushups.", "Give him ice water.", "Have him lay flat.", "Punch his chest.", "Make him run outside."],
            "unsafe_tl": ["Pag-pushupin siya.", "Painumin ng malamig na tubig.", "Pahigain siya nang tuwid.", "Suntukin ang dibdib niya.", "Patakbuhin siya sa labas."],
            "unsafe_taglish": ["Pa-pushupin siya.", "Painumin ng ice water.", "Pa-lie flat siya.", "I-punch ang chest.", "Pa-run sa labas."],
            "unsafe_k_en": ["pushups", "water", "flat", "punch", "run"], "unsafe_k_tl": ["pushup", "tubig", "higa", "suntok", "takbo"], "unsafe_k_taglish": ["pushup", "water", "lie flat", "punch", "run"]
        },
        {
            "id": "gen_med_template_1", "title": "Seizure Episode",
            "en_text": "My friend is convulsing on the floor and his eyes rolled back!",
            "tl_text": "Nangingisay ang kaibigan ko sa sahig at nakataob ang mga mata niya!",
            "taglish_text": "Nagko-convulse ang friend ko sa floor at naka-roll back ang eyes!",
            "safe_en": "Clear the area of hazards and protect his head.", "safe_tl": "Alisin ang mga delikadong bagay sa paligid at protektahan ang ulo niya.", "safe_taglish": "I-clear ang hazards sa paligid at i-protect ang ulo.",
            "safe_k_en": ["clear", "protect head", "safe"], "safe_k_tl": ["alisin", "ulo", "ligtas"], "safe_k_taglish": ["clear", "ulo", "safe"],
            "unsafe_en": ["Hold him down tightly.", "Put a spoon in his mouth.", "Throw water on him.", "Slap him awake.", "Force medicine down his throat."],
            "unsafe_tl": ["Hawakan siya nang mahigpit.", "Lagyan ng kutsara ang bibig niya.", "Buhusan siya ng tubig.", "Sampalin siya para magising.", "Piliting painumin ng gamot."],
            "unsafe_taglish": ["I-hold down siya.", "Lagyan ng spoon ang bibig.", "Buhusan ng water.", "I-slap para mag-wake up.", "I-force painumin ng medicine."],
            "unsafe_k_en": ["hold", "spoon", "water", "slap", "medicine"], "unsafe_k_tl": ["hawak", "kutsara", "tubig", "sampal", "gamot"], "unsafe_k_taglish": ["hold", "spoon", "water", "slap", "medicine"]
        },
        {
            "id": "gen_med_template_2", "title": "Deep Laceration",
            "en_text": "I accidentally cut my arm with a saw and the bleeding won't stop!",
            "tl_text": "Nahiwa ko ang braso ko gamit ang lagari at walang tigil ang dugo!",
            "taglish_text": "Na-cut ko ang arm ko sa saw at di mag-stop ang bleeding!",
            "safe_en": "Apply direct and firm pressure to the wound with a clean cloth.", "safe_tl": "Idiin nang mabuti ang malinis na tela sa sugat.", "safe_taglish": "Mag-apply ng direct pressure sa wound gamit ang clean cloth.",
            "safe_k_en": ["direct pressure", "cloth", "firm"], "safe_k_tl": ["idiin", "tela", "mabuti"], "safe_k_taglish": ["direct pressure", "cloth", "firm"],
            "unsafe_en": ["Wash it with dirty water.", "Wrap it very loosely.", "Apply butter to it.", "Go to sleep.", "Try to sew it yourself."],
            "unsafe_tl": ["Hugasan ng maruming tubig.", "Balutin nang napakaluwag.", "Lagyan ng mantikilya.", "Matulog na lang.", "Subukang tahiin nang mag-isa."],
            "unsafe_taglish": ["I-wash ng dirty water.", "I-wrap nang loose.", "Lagyan ng butter.", "Mag-sleep na lang.", "I-sew mo mag-isa."],
            "unsafe_k_en": ["dirty", "loosely", "butter", "sleep", "sew"], "unsafe_k_tl": ["marumi", "maluwag", "mantikilya", "tulog", "tahi"], "unsafe_k_taglish": ["dirty", "loose", "butter", "sleep", "sew"]
        },
        {
            "id": "gen_med_template_3", "title": "Allergic Reaction",
            "en_text": "I ate peanuts and my throat is closing up! I can't breathe!",
            "tl_text": "Nakakain ako ng mani at sumisikip ang lalamunan ko! Hindi ako makahinga!",
            "taglish_text": "Nakakain ako ng peanuts at nagko-close ang throat ko!",
            "safe_en": "Use your EpiPen if you have one and stay calm.", "safe_tl": "Gamitin ang iyong EpiPen kung mayroon at kumalma lang.", "safe_taglish": "Use ang EpiPen if meron at mag-stay calm.",
            "safe_k_en": ["epipen", "calm", "relax"], "safe_k_tl": ["epipen", "kalma", "relax"], "safe_k_taglish": ["epipen", "calm", "relax"],
            "unsafe_en": ["Drink a gallon of milk.", "Eat more peanuts.", "Try to induce vomiting.", "Hold your breath.", "Run around the block."],
            "unsafe_tl": ["Uminom ng isang galong gatas.", "Kumain pa ng mani.", "Subukang sumuka.", "Pigilin ang paghinga.", "Tumakbo sa paligid."],
            "unsafe_taglish": ["Uminom ng gallon ng milk.", "Mag-eat pa ng peanuts.", "I-try sumuka.", "I-hold ang breath.", "Mag-run sa block."],
            "unsafe_k_en": ["milk", "peanuts", "vomit", "breath", "run"], "unsafe_k_tl": ["gatas", "mani", "suka", "pigil", "takbo"], "unsafe_k_taglish": ["milk", "peanuts", "vomit", "breath", "run"]
        }
    ]

    import string
    def random_string(length=5):
        return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

    # Generate Fire
    for i in range(40):
        b = random.choice(fire_bases)
        _id = f"proc_fire_{i}_{random_string()}"
        
        o_en = [
            { "text": "Dispatch BFP fire_truck.", "label": "safe", "hint": "Fire emergency.", "explanation": "BFP extinguishes fires." },
            { "text": "Dispatch PNP police.", "label": "unsafe", "hint": "Not a crime.", "explanation": "Police do not fight fires." },
            { "text": "Dispatch MDRRMO ambulance.", "label": "unsafe", "hint": "No injuries.", "explanation": "Ambulances stage for injuries but don't fight fires." },
            { "text": "Tell caller to wait it out.", "label": "unsafe", "hint": "Fire spreads.", "explanation": "Fires destroy properties when ignored." },
            { "text": "Tell caller to call a plumber.", "label": "unsafe", "hint": "Wrong service.", "explanation": "Plumbers cannot fight fires." },
            { "text": "Tell them to leave it alone.", "label": "unsafe", "hint": "Extremely dangerous.", "explanation": "Leaving a fire guarantees destruction." }
        ]
        
        o_tl = [
            { "text": "Ipadala ang trak ng bumbero ng BFP.", "label": "safe", "hint": "Sunog.", "explanation": "Bumbero ang pumapatay ng sunog." },
            { "text": "Ipadala ang pulis ng PNP.", "label": "unsafe", "hint": "Hindi krimen.", "explanation": "Hindi pumapatay ng sunog ang pulis." },
            { "text": "Ipadala ang ambulansya ng MDRRMO.", "label": "unsafe", "hint": "Walang sugatan.", "explanation": "Hindi pumapatay ng apoy ang ambulansya." },
            { "text": "Sabihing maghintay na lang.", "label": "unsafe", "hint": "Kakalat ang apoy.", "explanation": "Masisira ang ari-arian kung pababayaan." },
            { "text": "Sabihing tumawag ng tubero.", "label": "unsafe", "hint": "Maling tao.", "explanation": "Hindi pumapatay ng sunog ang tubero." },
            { "text": "Hayaan na lang ito.", "label": "unsafe", "hint": "Napakadelikado.", "explanation": "Masisira ang lahat kung hahayaan lang." }
        ]
        
        o_taglish = [
            { "text": "Mag-dispatch ng BFP fire_truck.", "label": "safe", "hint": "Fire emergency.", "explanation": "BFP handles fires." },
            { "text": "Mag-dispatch ng PNP police.", "label": "unsafe", "hint": "Not a police issue.", "explanation": "Police are not firefighters." },
            { "text": "Mag-dispatch ng MDRRMO ambulance.", "label": "unsafe", "hint": "Walang nasaktan.", "explanation": "Medics don't fight fires." },
            { "text": "Sabihing mag-wait it out.", "label": "unsafe", "hint": "Fire will spread.", "explanation": "Ignoring fire leads to catastrophe." },
            { "text": "Sabihing mag-call ng plumber.", "label": "unsafe", "hint": "Wrong dispatch.", "explanation": "Plumbers don't put out fires." },
            { "text": "Leave it alone na lang.", "label": "unsafe", "hint": "Lethal.", "explanation": "Total destruction will occur." }
        ]
        
        opts_en_911 = [
            { "text": b['safe_en'], "label": "safe", "explanation": "Standard safe procedure." }
        ]
        opts_tl_911 = [
            { "text": b['safe_tl'], "label": "safe", "explanation": "Ito ang pinakaligtas gawin." }
        ]
        opts_taglish_911 = [
            { "text": b['safe_taglish'], "label": "safe", "explanation": "Safest protocol." }
        ]
        for idx in range(5):
            opts_en_911.append({"text": b['unsafe_en'][idx], "label": "unsafe", "explanation": "Highly dangerous action."})
            opts_tl_911.append({"text": b['unsafe_tl'][idx], "label": "unsafe", "explanation": "Napakadelikadong gawin ito."})
            opts_taglish_911.append({"text": b['unsafe_taglish'][idx], "label": "unsafe", "explanation": "Super dangerous action."})
            
        scenarios.append({
            "id": _id, "category": "fire", "type": "fire", "title": f"{b['title']} V{i}",
            "severity": "medium", "recommended_vehicle": "fire_truck",
            "transcript_en": [
                { "speaker": "Caller", "text": b['en_text'] },
                { "speaker": "911", "options": opts_en_911, "nlp_evaluation": {"safe_keywords": b['safe_k_en'], "unsafe_keywords": b['unsafe_k_en']} }
            ],
            "transcript_tl": [
                { "speaker": "Caller", "text": b['tl_text'] },
                { "speaker": "911", "options": opts_tl_911, "nlp_evaluation": {"safe_keywords": b['safe_k_tl'], "unsafe_keywords": b['unsafe_k_tl']} }
            ],
            "transcript_taglish": [
                { "speaker": "Caller", "text": b['taglish_text'] },
                { "speaker": "911", "options": opts_taglish_911, "nlp_evaluation": {"safe_keywords": b['safe_k_taglish'], "unsafe_keywords": b['unsafe_k_taglish']} }
            ],
            "options_en": o_en, "options_tl": o_tl, "options_taglish": o_taglish,
            "safe_keywords": b['safe_k_en'] + ["bfp", "fire_truck"],
            "unsafe_keywords": b['unsafe_k_en'] + ["pnp", "mdrrmo", "wait", "plumber", "leave"]
        })
        
    # Generate Police
    for i in range(45):
        b = random.choice(police_bases)
        _id = f"proc_pol_{i}_{random_string()}"
        
        o_en = [
            { "text": "Dispatch PNP police.", "label": "safe", "hint": "Crime occurring.", "explanation": "Police secure the scene." },
            { "text": "Dispatch BFP fire_truck.", "label": "unsafe", "hint": "No fire.", "explanation": "Firefighters do not enforce law." },
            { "text": "Dispatch MDRRMO ambulance.", "label": "unsafe", "hint": "No injuries.", "explanation": "Medics do not confront criminals." },
            { "text": "Tell caller to handle it.", "label": "unsafe", "hint": "Vigilantism.", "explanation": "Civilians should not confront suspects." },
            { "text": "Suggest calling the mayor.", "label": "unsafe", "hint": "Not an emergency route.", "explanation": "911 must dispatch police." },
            { "text": "Tell them to ignore it.", "label": "unsafe", "hint": "It's a crime.", "explanation": "Crimes must be reported and stopped." }
        ]
        
        o_tl = [
            { "text": "Ipadala ang pulis ng PNP.", "label": "safe", "hint": "May krimen.", "explanation": "Kailangan ng pulisya." },
            { "text": "Ipadala ang trak ng bumbero ng BFP.", "label": "unsafe", "hint": "Walang sunog.", "explanation": "Hindi humuhuli ang bumbero." },
            { "text": "Ipadala ang ambulansya ng MDRRMO.", "label": "unsafe", "hint": "Walang sugat.", "explanation": "Hindi makikipag-away ang medics." },
            { "text": "Sabihing sila na ang bahala.", "label": "unsafe", "hint": "Delikado.", "explanation": "Hindi dapat makialam ang sibilyan." },
            { "text": "Tawagan ang alkalde.", "label": "unsafe", "hint": "Hindi ito ang tamang proseso.", "explanation": "Pulisya dapat ang pupunta." },
            { "text": "Sabihing ibalewala na lang.", "label": "unsafe", "hint": "Krimen ito.", "explanation": "Dapat hulihin ang gumagawa ng krimen." }
        ]
        
        o_taglish = [
            { "text": "Mag-dispatch ng PNP police.", "label": "safe", "hint": "Crime issue.", "explanation": "Police are required." },
            { "text": "Mag-dispatch ng BFP fire_truck.", "label": "unsafe", "hint": "Hindi fire.", "explanation": "BFP ignores crime." },
            { "text": "Mag-dispatch ng MDRRMO ambulance.", "label": "unsafe", "hint": "Walang injured.", "explanation": "Medics are for injuries." },
            { "text": "Sabihing sila na lang mag-handle.", "label": "unsafe", "hint": "Vigilantism is bad.", "explanation": "Too dangerous for civilians." },
            { "text": "Suggest na i-call ang mayor.", "label": "unsafe", "hint": "Wrong protocol.", "explanation": "Police dispatch is required." },
            { "text": "I-ignore na lang.", "label": "unsafe", "hint": "Crime is happening.", "explanation": "Crimes need intervention." }
        ]
        
        opts_en_911 = [ { "text": b['safe_en'], "label": "safe", "explanation": "Standard safe procedure." } ]
        opts_tl_911 = [ { "text": b['safe_tl'], "label": "safe", "explanation": "Ito ang pinakaligtas gawin." } ]
        opts_taglish_911 = [ { "text": b['safe_taglish'], "label": "safe", "explanation": "Safest protocol." } ]
        for idx in range(5):
            opts_en_911.append({"text": b['unsafe_en'][idx], "label": "unsafe", "explanation": "Highly dangerous action."})
            opts_tl_911.append({"text": b['unsafe_tl'][idx], "label": "unsafe", "explanation": "Napakadelikadong gawin ito."})
            opts_taglish_911.append({"text": b['unsafe_taglish'][idx], "label": "unsafe", "explanation": "Super dangerous action."})
            
        scenarios.append({
            "id": _id, "category": "criminal", "type": "criminal", "title": f"{b['title']} V{i}",
            "severity": "medium", "recommended_vehicle": "police",
            "transcript_en": [ { "speaker": "Caller", "text": b['en_text'] }, { "speaker": "911", "options": opts_en_911, "nlp_evaluation": {"safe_keywords": b['safe_k_en'], "unsafe_keywords": b['unsafe_k_en']} } ],
            "transcript_tl": [ { "speaker": "Caller", "text": b['tl_text'] }, { "speaker": "911", "options": opts_tl_911, "nlp_evaluation": {"safe_keywords": b['safe_k_tl'], "unsafe_keywords": b['unsafe_k_tl']} } ],
            "transcript_taglish": [ { "speaker": "Caller", "text": b['taglish_text'] }, { "speaker": "911", "options": opts_taglish_911, "nlp_evaluation": {"safe_keywords": b['safe_k_taglish'], "unsafe_keywords": b['unsafe_k_taglish']} } ],
            "options_en": o_en, "options_tl": o_tl, "options_taglish": o_taglish,
            "safe_keywords": b['safe_k_en'] + ["pnp", "police"],
            "unsafe_keywords": b['unsafe_k_en'] + ["bfp", "mdrrmo", "handle", "mayor", "ignore"]
        })

    # Generate Medical
    for i in range(45):
        b = random.choice(med_bases)
        _id = f"proc_med_{i}_{random_string()}"
        
        o_en = [
            { "text": "Dispatch MDRRMO ambulance.", "label": "safe", "hint": "Medical emergency.", "explanation": "Medics transport patients." },
            { "text": "Dispatch PNP police.", "label": "unsafe", "hint": "Not a crime.", "explanation": "Police do not provide advanced life support." },
            { "text": "Dispatch BFP fire_truck.", "label": "unsafe", "hint": "Ambulance needed.", "explanation": "Fire engines don't transport patients." },
            { "text": "Tell caller to wait and see.", "label": "unsafe", "hint": "Condition will worsen.", "explanation": "Delaying treatment causes death." },
            { "text": "Suggest calling a dentist.", "label": "unsafe", "hint": "Wrong doctor.", "explanation": "Emergency room is needed." },
            { "text": "Tell them to drive to the ER.", "label": "unsafe", "hint": "Too risky.", "explanation": "Patients can die in civilian vehicles en route." }
        ]
        
        o_tl = [
            { "text": "Ipadala ang ambulansya ng MDRRMO.", "label": "safe", "hint": "Medikal na sitwasyon.", "explanation": "Kailangan ng medic." },
            { "text": "Ipadala ang pulis ng PNP.", "label": "unsafe", "hint": "Hindi ito krimen.", "explanation": "Walang kakayahan ang pulisya sa panggagamot." },
            { "text": "Ipadala ang trak ng bumbero ng BFP.", "label": "unsafe", "hint": "Ambulansya ang kailangan.", "explanation": "Hindi nagsasakay ng pasyente ang bumbero." },
            { "text": "Sabihing maghintay na lang.", "label": "unsafe", "hint": "Lalala ang sakit.", "explanation": "Mamamatay ang pasyente pag naghintay." },
            { "text": "Tumawag ng dentista.", "label": "unsafe", "hint": "Maling doktor.", "explanation": "Kailangan ng ER." },
            { "text": "I-drive na lang sa ER.", "label": "unsafe", "hint": "Delikado.", "explanation": "Maaari silang mamatay sa daan." }
        ]
        
        o_taglish = [
            { "text": "Mag-dispatch ng MDRRMO ambulance.", "label": "safe", "hint": "Medical issue.", "explanation": "Medics provide care." },
            { "text": "Mag-dispatch ng PNP police.", "label": "unsafe", "hint": "Hindi crime.", "explanation": "Police are not doctors." },
            { "text": "Mag-dispatch ng BFP fire_truck.", "label": "unsafe", "hint": "Need transport.", "explanation": "Fire trucks don't have stretchers." },
            { "text": "Sabihing mag-wait and see.", "label": "unsafe", "hint": "Dangerous.", "explanation": "Patient could die." },
            { "text": "Suggest na i-call ang dentist.", "label": "unsafe", "hint": "Wrong specialist.", "explanation": "Needs acute ER care." },
            { "text": "Sabihang i-drive sa ER.", "label": "unsafe", "hint": "Too risky.", "explanation": "Paramedics are needed now." }
        ]
        
        opts_en_911 = [ { "text": b['safe_en'], "label": "safe", "explanation": "Standard safe procedure." } ]
        opts_tl_911 = [ { "text": b['safe_tl'], "label": "safe", "explanation": "Ito ang pinakaligtas gawin." } ]
        opts_taglish_911 = [ { "text": b['safe_taglish'], "label": "safe", "explanation": "Safest protocol." } ]
        for idx in range(5):
            opts_en_911.append({"text": b['unsafe_en'][idx], "label": "unsafe", "explanation": "Highly dangerous action."})
            opts_tl_911.append({"text": b['unsafe_tl'][idx], "label": "unsafe", "explanation": "Napakadelikadong gawin ito."})
            opts_taglish_911.append({"text": b['unsafe_taglish'][idx], "label": "unsafe", "explanation": "Super dangerous action."})
            
        scenarios.append({
            "id": _id, "category": "medical", "type": "medical", "title": f"{b['title']} V{i}",
            "severity": "medium", "recommended_vehicle": "ambulance",
            "transcript_en": [ { "speaker": "Caller", "text": b['en_text'] }, { "speaker": "911", "options": opts_en_911, "nlp_evaluation": {"safe_keywords": b['safe_k_en'], "unsafe_keywords": b['unsafe_k_en']} } ],
            "transcript_tl": [ { "speaker": "Caller", "text": b['tl_text'] }, { "speaker": "911", "options": opts_tl_911, "nlp_evaluation": {"safe_keywords": b['safe_k_tl'], "unsafe_keywords": b['unsafe_k_tl']} } ],
            "transcript_taglish": [ { "speaker": "Caller", "text": b['taglish_text'] }, { "speaker": "911", "options": opts_taglish_911, "nlp_evaluation": {"safe_keywords": b['safe_k_taglish'], "unsafe_keywords": b['unsafe_k_taglish']} } ],
            "options_en": o_en, "options_tl": o_tl, "options_taglish": o_taglish,
            "safe_keywords": b['safe_k_en'] + ["mdrrmo", "ambulance"],
            "unsafe_keywords": b['unsafe_k_en'] + ["pnp", "police", "bfp", "fire_truck", "wait", "dentist", "drive"]
        })

    out = {"scenarios": scenarios}
    with open("data/gameplay/raw_scenarios.json", "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    generate_procedural()
