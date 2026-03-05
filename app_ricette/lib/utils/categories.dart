const Map<String, List<String>> categoryMapData = {
  // --- BEVANDE ---
  '💧': ['water', 'acqua', 'idrolitina'],
  '☕': ['coffee', 'caffe', 'caffè', 'espresso', 'caffeine', 'caffeina'],
  '🍵': ['tea', 'te', 'tè', 'matcha', 'tisana', 'camomilla'],
  '🍷': ['wine', 'vino', 'prosecco', 'champagne', 'spumante', 'rosso', 'bianco'],
  '🍺': ['beer', 'birra', 'ipa', 'lager', 'ale'],
  '🥛': ['milk', 'latte', 'panna', 'cream', 'yogurt', 'kefir', 'soia', 'avena', 'mandorla'],
  '🧃': ['juice', 'succo', 'spremuta', 'soda', 'coca', 'aranciata', 'bibita', 'drink'],

  // --- CARBOIDRATI ---
  '🍝': ['pasta', 'spaghetti', 'penne', 'fusilli', 'ravioli', 'lasagna', 'maccheroni', 'gnocchi', 'tortellini', 'cappelletti', 'tagliatelle', 'pappardelle', 'orecchiette', 'pasta fresca', 'pasta all\'uovo'],
  '🍚': ['rice', 'riso', 'risotto', 'basmati', 'couscous', 'farro', 'orzo'],
  '🍕': ['pizza', 'focaccia', 'calzone'],
  '🥖': ['bread', 'pane', 'panino', 'baguette', 'ciabatta', 'toast', 'rosetta', 'farina', 'flour', '00',
         'integrale', 'lievito', 'yeast', 'baking powder', 'amido', 'fecola', 'piadina', 'tigelle', 'grissini'],
  '🍪': ['cookie', 'biscuit', 'biscotti', 'biscotto', 'wafer', 'cracker', 'taralli', 'fette biscottate'],
  '🥐': ['croissant', 'brioche', 'cornetto', 'muffin', 'pancake', 'merendina'],
  '🍰': ['cake', 'torta', 'pie', 'crostata', 'tiramisu', 'dolce', 'pasticcino'],
  '🍫': ['chocolate', 'cioccolato', 'cacao', 'nutella', 'barretta', 'kinder'],
  '🍦': ['ice cream', 'gelato', 'sorbetto', 'ghiacciolo'],
  '🥣': ['cereal', 'cereali', 'cornflakes', 'muesli', 'porridge', 'avena', 'oats', 'zuppa', 'minestrone', 'vellutata'],
  '🥯': ['bagel', 'donut', 'ciambella'],

  // --- PROTEINE & FRESCHI ---
  '🧀': ['cheese', 'formaggio', 'mozzarella', 'parmigiano', 'grana', 'burro', 'ricotta', 'stracchino', 'gorgonzola'],
  '🥚': ['egg', 'uova', 'uovo', 'albume', 'tuorlo'],
  '🍗': ['chicken', 'pollo', 'tacchino', 'turkey', 'alette', 'fuso'],
  '🥓': ['bacon', 'pancetta', 'prosciutto', 'salame', 'salsiccia', 'wurstel', 'mortadella', 'speck', 'affettato'],
  '🥩': ['meat', 'carne', 'manzo', 'bistecca', 'vitello', 'macinato', 'hamburger', 'svizzera', 'maiale', 'pork',
         'suino', 'agnello', 'lamb', 'costine', 'ribs', 'filetto', 'fillet', 'controfiletto', 'sirloin', 'tagliata', 'arrosto', 'roastbeef', 'macinato', 'minced', 'polpette', 'meatballs', 'spiedini', 'carpaccio', 'tartare'],
  '🐟': ['fish', 'pesce', 'tonno', 'salmone', 'merluzzo', 'orata', 'spigola', 'sogliola', 'branzino', 'polpo', 'octopus', 'calamari', 'squid', 'seppie', 'alici', 'acciughe', 'anchovy', 'baccala', 'trota', 'trout', 'pesce spada', 'swordfish'],
  '🦐': ['shrimp', 'gamberi', 'gamberetto', 'cozze', 'vongole', 'crostacei', 'mare'],

  // --- ORTOFRUTTA ---
  '🥗': ['salad', 'insalata', 'lattuga', 'rucola', 'spinaci', 'valeriana'],
  '🍅': ['tomato', 'pomodoro', 'pomodori', 'pomodorini', 'salsa', 'passata'],
  '🥔': ['potato', 'patata', 'patate', 'cipolla', 'onion', 'aglio', 'garlic', 'carota', 'carrot', 'patate dolci', 'sweet potato', 'scalogno', 'shallot', 'topinambur'],
  '🥦': ['broccoli', 'cavolfiore', 'zucchine', 'zucchini', 'cetriolo', 'verza', 'fagioli', 'piselli',
         'legumi', 'verdura', 'melanzana', 'melanzane', 'eggplant', 'aubergine', 'peperoni', 'peppers', 'zucca', 'pumpkin', 'finocchio', 'fennel', 'carciofi', 'artichoke', 'asparagi', 'asparagus', 'sedano', 'celery', 'bietole', 'chard', 'cicoria', 'radicchio', 'cavolo', 'cabbage', 'cavoletti'],
  '🍄': ['mushroom', 'funghi', 'porcini', 'champignon'],
  '🌽': ['corn', 'mais', 'pannocchia'],

  // FRUTTA
  '🍎': ['apple', 'mela', 'mele'],
  '🍐': ['pear', 'pera', 'pere'],
  '🍌': ['banana', 'banane'],
  '🍋': ['lemon', 'limone', 'arancia', 'orange', 'mandarino', 'pompelmo', 'agrumi'],
  '🍇': ['grape', 'uva'],
  '🍓': ['strawberry', 'fragola', 'fragole', 'frutti di bosco'],
  '🍑': ['peach', 'pesca', 'albicocca'],
  '🍉': ['watermelon', 'anguria', 'cocomero', 'melone'],
  '🥑': ['avocado'],
  '🍍': ['ananas', 'pineapple'],

  // --- DISPENSA ---
  '🫒': ['oil', 'olio', 'aceto', 'vinegar'],
  '🌿': ['herb', 'erbe', 'aromi', 'basilico', 'basil', 'prezzemolo', 'parsley', 'rosmarino', 'rosemary', 'salvia', 'sage', 'menta', 'mint', 'origano', 'oregano', 'timo', 'thyme', 'alloro', 'curry', 'paprika', 'cannella', 'cinnamon', 'zafferano', 'saffron', 'zenzero', 'ginger'],
  '🧂': ['salt', 'sale', 'pepe', 'pepper', 'zucchero', 'sugar'],
  '🥫': ['sauce', 'sugo', 'ragu', 'pesto', 'maionese', 'ketchup', 'tonno in scatola', 'fagioli in scatola'],
  '🍯': ['honey', 'miele', 'jam', 'marmellata', 'confettura'],

  // --- NUTS ---
  '🥜': ['nut', 'noci', 'mandorle', 'almond', 'pistacchi', 'pistachio', 'arachidi', 'peanuts', 'nocciole', 'anacardi', 'cashew', 'burro di arachidi', 'semi'],
  '🌰': ['castagne', 'chestnut'],

  // --- SNACK ---
  '🍟': ['chips', 'patatine', 'patatine fritte', 'fries', 'nachos', 'tortilla'],
  '🍿': ['popcorn', 'mais scoppiato'],
  '🥨': ['pretzel', 'salatini', 'cracker salati'],

  // --- ASIAN FOOD ---
  '🍣': ['sushi', 'sashimi', 'nori', 'alga', 'wasabi', 'zenzero marinato'],
  '🍱': ['bento', 'pokè', 'poke', 'riso per sushi'],
  '🥟': ['dumpling', 'ravioli cinesi', 'gyoza', 'involtini primavera'],
  '🍜': ['ramen', 'noodles', 'spaghettini di soia', 'cup noodles'],
  '🌮': ['taco', 'burrito', 'tortilla', 'fajita', 'mexican'],

  // --- SPICY ---
  '🌶️': ['chili', 'peperoncino', 'jalapeno', 'habanero', 'tabasco', 'piccante', 'spicy'],

  // --- FROZEN ---
  '🧊': ['ice', 'ghiaccio', 'surgelati', 'frozen', 'minestrone surgelato'],
};