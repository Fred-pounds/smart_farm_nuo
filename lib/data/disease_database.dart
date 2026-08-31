import '../models/disease.dart';

/// Treatment knowledge keyed by PlantVillage class label — the same strings
/// that appear in `assets/models/labels.txt`.
///
/// Crops outside this list still resolve through [DiseaseInfo.unknown], which
/// parses the label into a crop and disease name, so an unmapped class
/// degrades to a readable result rather than an error.
class DiseaseDatabase {
  const DiseaseDatabase._();

  static const Map<String, DiseaseInfo> _byLabel = {
    // ---------------------------------------------------------------- Tomato
    'Tomato___Late_blight': DiseaseInfo(
      label: 'Tomato___Late_blight',
      cropName: 'Tomato',
      diseaseName: 'Late Blight',
      severity: DiseaseSeverity.high,
      description:
          'A fast-moving oomycete (Phytophthora infestans) that can destroy a '
          'whole field within a week in cool, wet, humid weather. Act the same '
          'day you see it.',
      symptoms: [
        'Large greasy grey-green blotches on leaves that turn brown-black',
        'White fuzzy growth on the leaf underside in humid mornings',
        'Dark greasy patches on stems and fruit',
        'Whole plant collapse within days',
      ],
      organicTreatment: [
        'Remove and burn infected plants immediately — do not compost them',
        'Apply copper oxychloride every 5–7 days while conditions stay humid',
        'Stop overhead watering; irrigate at the base only',
        'Increase spacing to open the canopy and dry the leaves faster',
      ],
      chemicalTreatment: [
        'Mancozeb 80% WP as a protectant on unaffected plants',
        'Metalaxyl + Mancozeb for active infection',
        'Alternate active ingredients to avoid resistance',
        'Observe the pre-harvest interval on the label',
      ],
      prevention: [
        'Plant resistant varieties where available',
        'Avoid overhead irrigation entirely',
        'Rotate away from tomato and potato for 2–3 seasons',
        'Stake plants so air moves through the canopy',
      ],
    ),
    'Tomato___Early_blight': DiseaseInfo(
      label: 'Tomato___Early_blight',
      cropName: 'Tomato',
      diseaseName: 'Early Blight',
      severity: DiseaseSeverity.moderate,
      description:
          'A fungal leaf spot (Alternaria solani) that starts on the oldest '
          'leaves and works upward. Slower than late blight, but it steadily '
          'strips the plant of the leaves it needs to fill fruit.',
      symptoms: [
        'Brown spots with concentric rings, like a target',
        'Yellow halo around each spot',
        'Lower, older leaves affected first',
        'Dark sunken lesions on the stem end of fruit',
      ],
      organicTreatment: [
        'Strip and destroy the affected lower leaves',
        'Spray neem oil or a copper fungicide weekly',
        'Mulch heavily to stop soil splashing spores onto leaves',
        'Feed with compost — well-nourished plants resist it better',
      ],
      chemicalTreatment: [
        'Chlorothalonil every 7–10 days',
        'Mancozeb as a protectant',
        'Azoxystrobin for severe cases',
      ],
      prevention: [
        'Rotate crops on a 3-year cycle',
        'Mulch to break the soil-to-leaf splash path',
        'Space plants for airflow',
        'Remove all crop debris at the end of the season',
      ],
    ),
    'Tomato___Bacterial_spot': DiseaseInfo(
      label: 'Tomato___Bacterial_spot',
      cropName: 'Tomato',
      diseaseName: 'Bacterial Spot',
      severity: DiseaseSeverity.high,
      description:
          'Seed- and splash-borne Xanthomonas bacteria. Fungicides do not '
          'touch it — copper plus strict sanitation is the only real control.',
      symptoms: [
        'Small dark water-soaked spots on leaves, later turning angular',
        'Raised scabby spots on fruit',
        'Leaf edges yellowing and dying back',
        'Spread accelerates after rain or overhead watering',
      ],
      organicTreatment: [
        'Copper hydroxide sprays, repeated every 7 days',
        'Remove infected plants and all fallen debris',
        'Never work in the field while the plants are wet — you spread it',
        'Disinfect tools and hands between rows',
      ],
      chemicalTreatment: [
        'Copper + Mancozeb tank mix',
        'Streptomycin only where locally permitted for agricultural use',
      ],
      prevention: [
        'Use certified disease-free seed',
        'Hot-water treat seed before sowing (50 °C for 25 minutes)',
        'Avoid overhead irrigation',
        'Rotate away from tomato and pepper for 2 years',
      ],
    ),
    'Tomato___Leaf_Mold': DiseaseInfo(
      label: 'Tomato___Leaf_Mold',
      cropName: 'Tomato',
      diseaseName: 'Leaf Mould',
      severity: DiseaseSeverity.moderate,
      description:
          'Fungal disease (Passalora fulva) driven almost entirely by high '
          'humidity. Fix the ventilation and you fix the disease.',
      symptoms: [
        'Pale yellow patches on the upper leaf surface',
        'Olive-green to brown velvety mould on the underside',
        'Leaves curl, dry and drop',
      ],
      organicTreatment: [
        'Improve airflow — prune lower leaves and widen spacing',
        'Reduce humidity: water in the morning, never in the evening',
        'Copper fungicide spray',
      ],
      chemicalTreatment: ['Chlorothalonil', 'Mancozeb'],
      prevention: [
        'Keep relative humidity below 85% where you can control it',
        'Wide spacing and aggressive pruning',
        'Grow resistant varieties',
      ],
    ),
    'Tomato___Septoria_leaf_spot': DiseaseInfo(
      label: 'Tomato___Septoria_leaf_spot',
      cropName: 'Tomato',
      diseaseName: 'Septoria Leaf Spot',
      severity: DiseaseSeverity.moderate,
      description:
          'Very common fungal spotting that defoliates from the bottom up, '
          'exposing fruit to sunscald.',
      symptoms: [
        'Many small circular spots with dark borders and grey centres',
        'Tiny black specks (fruiting bodies) visible in the spot centres',
        'Starts on the lowest leaves after the first fruit sets',
      ],
      organicTreatment: [
        'Remove infected leaves at the first sign',
        'Copper or neem spray every 7–10 days',
        'Mulch to stop rain splash',
      ],
      chemicalTreatment: ['Chlorothalonil every 7–10 days', 'Mancozeb'],
      prevention: [
        'Rotate crops',
        'Clear all debris at season end',
        'Water at the base only',
      ],
    ),
    'Tomato___Spider_mites Two-spotted_spider_mite': DiseaseInfo(
      label: 'Tomato___Spider_mites Two-spotted_spider_mite',
      cropName: 'Tomato',
      diseaseName: 'Two-Spotted Spider Mite',
      severity: DiseaseSeverity.moderate,
      description:
          'A sap-sucking mite, not a disease. Populations explode in hot dry '
          'weather and on dusty, water-stressed plants.',
      symptoms: [
        'Fine yellow stippling across the leaf surface',
        'Fine webbing on the underside and between stems',
        'Leaves turn bronze and dry out',
      ],
      organicTreatment: [
        'Spray the leaf undersides forcefully with water',
        'Insecticidal soap or neem oil, repeated every 5 days',
        'Release predatory mites where available',
      ],
      chemicalTreatment: [
        'Abamectin',
        'Specific miticides — ordinary insecticides will not work and often '
            'make it worse by killing predators',
      ],
      prevention: [
        'Keep plants properly watered — drought stress invites mites',
        'Control dust on field roads and edges',
        'Avoid broad-spectrum insecticides that kill natural predators',
      ],
    ),
    'Tomato___Target_Spot': DiseaseInfo(
      label: 'Tomato___Target_Spot',
      cropName: 'Tomato',
      diseaseName: 'Target Spot',
      severity: DiseaseSeverity.moderate,
      description:
          'Fungal disease (Corynespora cassiicola) favoured by warm wet '
          'conditions, attacking leaves, stems and fruit.',
      symptoms: [
        'Brown spots with light centres and concentric rings',
        'Sunken circular lesions on fruit',
        'Heavy defoliation in humid weather',
      ],
      organicTreatment: [
        'Remove affected foliage',
        'Copper fungicide',
        'Improve airflow through pruning',
      ],
      chemicalTreatment: ['Chlorothalonil', 'Azoxystrobin'],
      prevention: [
        'Rotate crops',
        'Avoid overhead irrigation',
        'Destroy crop residue',
      ],
    ),
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus': DiseaseInfo(
      label: 'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
      cropName: 'Tomato',
      diseaseName: 'Yellow Leaf Curl Virus',
      severity: DiseaseSeverity.high,
      description:
          'Whitefly-transmitted virus. There is no cure — infected plants must '
          'be removed, and control means controlling the whitefly.',
      symptoms: [
        'Leaves curl upward and inward, cupping',
        'Severe stunting and bushy growth',
        'Yellow leaf margins',
        'Flowers drop; almost no fruit set',
      ],
      organicTreatment: [
        'Pull and destroy infected plants immediately',
        'Yellow sticky traps for whitefly',
        'Neem oil against whitefly nymphs',
        'Reflective silver mulch repels whitefly',
      ],
      chemicalTreatment: [
        'Imidacloprid to control the whitefly vector',
        'No chemical cures the virus itself',
      ],
      prevention: [
        'Plant TYLCV-resistant varieties',
        'Use insect-proof netting on nurseries',
        'Control whitefly from the seedling stage',
        'Keep a crop-free break between seasons',
      ],
    ),
    'Tomato___Tomato_mosaic_virus': DiseaseInfo(
      label: 'Tomato___Tomato_mosaic_virus',
      cropName: 'Tomato',
      diseaseName: 'Mosaic Virus',
      severity: DiseaseSeverity.high,
      description:
          'Extremely stable virus spread mainly by handling — hands, tools and '
          'even tobacco products. No cure once a plant is infected.',
      symptoms: [
        'Light and dark green mottling across the leaves',
        'Leaves narrow, distorted or fern-like',
        'Stunted growth, mottled and uneven fruit ripening',
      ],
      organicTreatment: [
        'Remove and destroy infected plants',
        'Wash hands with soap before handling healthy plants',
        'Disinfect tools with 10% bleach solution',
      ],
      chemicalTreatment: ['None — no chemical controls plant viruses'],
      prevention: [
        'Use certified virus-free seed',
        'No smoking or tobacco handling near the crop',
        'Sterilise tools and stakes between plants',
        'Grow resistant varieties',
      ],
    ),
    'Tomato___healthy': DiseaseInfo(
      label: 'Tomato___healthy',
      cropName: 'Tomato',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Keep scouting weekly — most tomato diseases are cheapest to stop early',
        'Maintain even soil moisture to prevent blossom-end rot',
        'Keep mulch in place',
      ],
    ),

    // ---------------------------------------------------------------- Potato
    'Potato___Late_blight': DiseaseInfo(
      label: 'Potato___Late_blight',
      cropName: 'Potato',
      diseaseName: 'Late Blight',
      severity: DiseaseSeverity.high,
      description:
          'The same pathogen as tomato late blight, and just as destructive. '
          'It moves from foliage into the tubers, rotting them in storage.',
      symptoms: [
        'Dark water-soaked lesions on leaves with pale green margins',
        'White mould on leaf undersides in humid weather',
        'Reddish-brown granular rot inside tubers',
      ],
      organicTreatment: [
        'Destroy infected foliage immediately',
        'Copper fungicide on a preventive schedule',
        'Earth up ridges well so spores cannot reach the tubers',
      ],
      chemicalTreatment: [
        'Mancozeb as a protectant',
        'Metalaxyl + Mancozeb curatively',
      ],
      prevention: [
        'Plant certified seed tubers',
        'Earth up generously',
        'Destroy volunteer potato plants and cull piles',
        'Harvest only in dry conditions',
      ],
    ),
    'Potato___Early_blight': DiseaseInfo(
      label: 'Potato___Early_blight',
      cropName: 'Potato',
      diseaseName: 'Early Blight',
      severity: DiseaseSeverity.moderate,
      description:
          'Alternaria leaf spot that mainly hits older foliage and stressed '
          'plants, cutting tuber bulking.',
      symptoms: [
        'Dark target-like spots on lower leaves',
        'Yellowing between the lesions',
        'Dry sunken lesions on tubers',
      ],
      organicTreatment: [
        'Remove affected lower foliage',
        'Copper fungicide every 7–10 days',
        'Maintain good fertility — hungry plants get hit hardest',
      ],
      chemicalTreatment: ['Chlorothalonil', 'Mancozeb', 'Azoxystrobin'],
      prevention: [
        'Rotate on a 3-year cycle',
        'Keep nitrogen adequate',
        'Irrigate at the base',
      ],
    ),
    'Potato___healthy': DiseaseInfo(
      label: 'Potato___healthy',
      cropName: 'Potato',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected on this potato foliage.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Keep ridges earthed up',
        'Scout weekly during humid weather',
      ],
    ),

    // ----------------------------------------------------------------- Maize
    'Corn_(maize)___Northern_Leaf_Blight': DiseaseInfo(
      label: 'Corn_(maize)___Northern_Leaf_Blight',
      cropName: 'Maize',
      diseaseName: 'Northern Leaf Blight',
      severity: DiseaseSeverity.high,
      description:
          'Fungal blight producing long cigar-shaped lesions. Damaging when it '
          'reaches the ear leaf before or during grain fill.',
      symptoms: [
        'Long grey-green to tan cigar-shaped lesions running with the veins',
        'Lesions 3–15 cm long',
        'Starts on lower leaves and moves up',
      ],
      organicTreatment: [
        'Remove and destroy infected residue after harvest',
        'Rotate to a non-cereal crop such as cowpea',
        'Wider spacing to reduce leaf wetness duration',
      ],
      chemicalTreatment: [
        'Azoxystrobin or propiconazole at tasselling',
        'Only worth spraying if lesions reach the ear leaf before silking',
      ],
      prevention: [
        'Plant resistant hybrids',
        'Rotate out of maize for a season',
        'Plough in or remove crop residue',
      ],
    ),
    'Corn_(maize)___Common_rust_': DiseaseInfo(
      label: 'Corn_(maize)___Common_rust_',
      cropName: 'Maize',
      diseaseName: 'Common Rust',
      severity: DiseaseSeverity.moderate,
      description:
          'Wind-borne rust fungus. Usually cosmetic on mature plants, but '
          'costly if it strikes early on a susceptible variety.',
      symptoms: [
        'Small cinnamon-brown powdery pustules on both leaf surfaces',
        'Pustules rupture the leaf surface and rub off orange on your hand',
        'Heavy infection yellows the whole leaf',
      ],
      organicTreatment: [
        'Usually no action needed on mature plants',
        'Remove badly infected lower leaves',
      ],
      chemicalTreatment: [
        'Propiconazole or azoxystrobin, only if infection is early and severe',
      ],
      prevention: [
        'Plant resistant hybrids',
        'Plant early to escape peak rust pressure',
      ],
    ),
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot': DiseaseInfo(
      label: 'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
      cropName: 'Maize',
      diseaseName: 'Gray Leaf Spot',
      severity: DiseaseSeverity.high,
      description:
          'Residue-borne fungus that thrives in humid weather and no-till '
          'fields. One of the biggest yield robbers in continuous maize.',
      symptoms: [
        'Narrow rectangular grey-tan lesions bounded by the leaf veins',
        'Lesions run parallel to the leaf, unlike the cigar shape of NLB',
        'Severe blighting from the lower canopy upward',
      ],
      organicTreatment: [
        'Bury or remove residue after harvest',
        'Rotate away from maize for at least one season',
      ],
      chemicalTreatment: [
        'Strobilurin or triazole fungicide around tasselling',
      ],
      prevention: [
        'Rotate crops',
        'Plough in residue',
        'Choose tolerant hybrids',
        'Avoid very dense planting',
      ],
    ),
    'Corn_(maize)___healthy': DiseaseInfo(
      label: 'Corn_(maize)___healthy',
      cropName: 'Maize',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected on this maize leaf.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Scout the leaf whorl weekly for fall armyworm',
        'Keep irrigation steady through tasselling and silking',
      ],
    ),

    // ---------------------------------------------------------------- Pepper
    'Pepper,_bell___Bacterial_spot': DiseaseInfo(
      label: 'Pepper,_bell___Bacterial_spot',
      cropName: 'Pepper',
      diseaseName: 'Bacterial Spot',
      severity: DiseaseSeverity.high,
      description:
          'Xanthomonas bacteria spread by rain splash and handling. Causes '
          'severe leaf drop and unmarketable scabby fruit.',
      symptoms: [
        'Small water-soaked spots turning dark brown and angular',
        'Yellow halos around the spots',
        'Raised scabby lesions on fruit',
        'Heavy defoliation leading to sunscald',
      ],
      organicTreatment: [
        'Copper sprays every 7 days',
        'Remove infected plants and debris',
        'Stay out of the field when foliage is wet',
      ],
      chemicalTreatment: [
        'Copper + Mancozeb tank mix',
        'Fungicides alone are ineffective — this is bacterial',
      ],
      prevention: [
        'Certified disease-free seed',
        'Hot-water seed treatment',
        'Drip rather than overhead irrigation',
        'Rotate away from pepper and tomato for 2 years',
      ],
    ),
    'Pepper,_bell___healthy': DiseaseInfo(
      label: 'Pepper,_bell___healthy',
      cropName: 'Pepper',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected on this pepper plant.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Avoid overwatering — pepper roots rot easily',
        'Scout for aphids and thrips weekly',
      ],
    ),

    // ---------------------------------------------------------------- Squash
    'Squash___Powdery_mildew': DiseaseInfo(
      label: 'Squash___Powdery_mildew',
      cropName: 'Squash',
      diseaseName: 'Powdery Mildew',
      severity: DiseaseSeverity.moderate,
      description:
          'The one common fungal disease that prefers dry leaves and humid '
          'air, so it spreads even without rain.',
      symptoms: [
        'White powdery patches on the upper leaf surface',
        'Patches merge until the leaf is coated',
        'Leaves yellow, dry and die; fruit gets sunscald',
      ],
      organicTreatment: [
        'Milk spray (1 part milk to 9 parts water) weekly',
        'Potassium bicarbonate spray',
        'Neem oil',
        'Remove the worst-affected leaves',
      ],
      chemicalTreatment: ['Sulphur-based fungicide', 'Myclobutanil'],
      prevention: [
        'Wide spacing and full sun',
        'Resistant varieties',
        'Avoid excess nitrogen, which produces soft susceptible growth',
      ],
    ),

    // ----------------------------------------------------------------- Apple
    'Apple___Apple_scab': DiseaseInfo(
      label: 'Apple___Apple_scab',
      cropName: 'Apple',
      diseaseName: 'Apple Scab',
      severity: DiseaseSeverity.moderate,
      description:
          'A fungus (Venturia inaequalis) that overwinters in fallen leaves '
          'and releases spores during spring rain. Rarely kills the tree, but '
          'it disfigures fruit and strips leaves in a bad year.',
      symptoms: [
        'Olive-green velvety spots on leaves, later turning brown-black',
        'Spots with feathery, indistinct edges',
        'Corky scabbed lesions on fruit, sometimes cracking',
        'Early leaf drop by midsummer',
      ],
      organicTreatment: [
        'Rake and destroy fallen leaves to remove the overwintering source',
        'Sulphur or copper sprays from bud break, repeated through wet spells',
        'Prune to open the canopy so leaves dry quickly after rain',
      ],
      chemicalTreatment: [
        'Myclobutanil or difenoconazole on a protectant schedule',
        'Captan during the primary infection period',
        'Alternate active ingredients — scab develops resistance readily',
      ],
      prevention: [
        'Plant scab-resistant cultivars',
        'Clear leaf litter every autumn without fail',
        'Avoid overhead irrigation',
      ],
    ),
    'Apple___Black_rot': DiseaseInfo(
      label: 'Apple___Black_rot',
      cropName: 'Apple',
      diseaseName: 'Black Rot',
      severity: DiseaseSeverity.high,
      description:
          'A fungus (Botryosphaeria obtusa) that attacks leaves, fruit and '
          'wood. The cankers it forms on branches are the reservoir, so '
          'spraying alone will not clear it.',
      symptoms: [
        '"Frogeye" leaf spots — brown centres with purple margins',
        'Firm black rot on fruit, often in concentric rings',
        'Sunken cankers on branches with peeling bark',
        'Mummified fruit clinging to the tree over winter',
      ],
      organicTreatment: [
        'Prune out cankered wood well below the damage and burn it',
        'Remove every mummified fruit from the tree and the ground',
        'Copper sprays at bud break',
      ],
      chemicalTreatment: [
        'Captan or thiophanate-methyl from petal fall',
        'Treat pruning wounds promptly',
      ],
      prevention: [
        'Keep trees vigorous — stressed and winter-damaged wood invites it',
        'Sanitise pruning tools between trees',
        'Remove nearby dead or neglected apple wood',
      ],
    ),
    'Apple___Cedar_apple_rust': DiseaseInfo(
      label: 'Apple___Cedar_apple_rust',
      cropName: 'Apple',
      diseaseName: 'Cedar Apple Rust',
      severity: DiseaseSeverity.moderate,
      description:
          'A rust that needs both an apple and a juniper/cedar to complete '
          'its life cycle. Breaking that pairing is more effective than any '
          'spray.',
      symptoms: [
        'Bright yellow-orange spots on the upper leaf surface',
        'Spots developing raised orange tubes underneath',
        'Deformed or spotted fruit',
        'Gelatinous orange galls on nearby cedar or juniper in spring',
      ],
      organicTreatment: [
        'Remove cedar and juniper within a few hundred metres if you can',
        'Pick off galls from nearby junipers before they turn gelatinous',
        'Sulphur sprays from pink bud through to petal fall',
      ],
      chemicalTreatment: [
        'Myclobutanil during the spring infection window',
        'Repeat at label interval through wet spring weather',
      ],
      prevention: [
        'Plant rust-resistant apple cultivars',
        'Do not plant apples and ornamental junipers together',
      ],
    ),
    'Apple___healthy': DiseaseInfo(
      label: 'Apple___healthy',
      cropName: 'Apple',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Clear fallen leaves each autumn to break disease cycles',
        'Prune annually for an open canopy that dries fast',
        'Scout after every extended wet spell',
      ],
    ),

    // ------------------------------------------------------------- Blueberry
    'Blueberry___healthy': DiseaseInfo(
      label: 'Blueberry___healthy',
      cropName: 'Blueberry',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Keep soil acidic (pH 4.5–5.5) — poor colour is usually pH, not disease',
        'Mulch to hold even moisture',
        'Prune out old canes to keep air moving',
      ],
    ),

    // ---------------------------------------------------------------- Cherry
    'Cherry_(including_sour)___Powdery_mildew': DiseaseInfo(
      label: 'Cherry_(including_sour)___Powdery_mildew',
      cropName: 'Cherry',
      diseaseName: 'Powdery Mildew',
      severity: DiseaseSeverity.moderate,
      description:
          'A fungus that coats leaves and shoots in white growth. Unlike most '
          'fungal diseases it does not need free water, so it spreads in dry '
          'weather when humidity is high.',
      symptoms: [
        'White powdery patches on leaves and young shoots',
        'Distorted, curled or stunted new growth',
        'Affected leaves yellowing and dropping early',
        'White film on fruit in severe cases',
      ],
      organicTreatment: [
        'Sulphur or potassium bicarbonate sprays at first sign',
        'Neem oil on young growth',
        'Prune out badly affected shoots',
      ],
      chemicalTreatment: [
        'Myclobutanil or trifloxystrobin',
        'Begin at shuck fall and repeat per label',
      ],
      prevention: [
        'Prune for an open canopy and good airflow',
        'Avoid heavy nitrogen, which pushes susceptible soft growth',
        'Plant in full sun',
      ],
    ),
    'Cherry_(including_sour)___healthy': DiseaseInfo(
      label: 'Cherry_(including_sour)___healthy',
      cropName: 'Cherry',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Prune in dry weather to limit infection of the cuts',
        'Clear fallen leaves and fruit',
        'Watch new growth in humid spells for early mildew',
      ],
    ),

    // ----------------------------------------------------------------- Grape
    'Grape___Black_rot': DiseaseInfo(
      label: 'Grape___Black_rot',
      cropName: 'Grape',
      diseaseName: 'Black Rot',
      severity: DiseaseSeverity.high,
      description:
          'A fungus (Guignardia bidwellii) that can take an entire crop in a '
          'wet season. The critical window is from bloom until the berries '
          'are about pea-sized.',
      symptoms: [
        'Tan-brown circular leaf spots with dark borders and black specks',
        'Berries turning brown, then shrivelling into hard black mummies',
        'Dark elongated lesions on shoots and stems',
      ],
      organicTreatment: [
        'Remove every mummified berry from the vine and the ground',
        'Prune out infected canes during dormancy and burn them',
        'Copper sprays from early shoot growth through fruit set',
      ],
      chemicalTreatment: [
        'Myclobutanil or mancozeb from bloom to bunch closure',
        'Maintain the schedule through the pre-bloom to pea-size window',
      ],
      prevention: [
        'Rigorous dormant sanitation — mummies are the whole inoculum source',
        'Train vines high with an open canopy',
        'Avoid overhead irrigation',
      ],
    ),
    'Grape___Esca_(Black_Measles)': DiseaseInfo(
      label: 'Grape___Esca_(Black_Measles)',
      cropName: 'Grape',
      diseaseName: 'Esca (Black Measles)',
      severity: DiseaseSeverity.high,
      description:
          'A trunk disease caused by a complex of wood-rotting fungi. There '
          'is no spray cure — it lives inside the permanent wood, and vines '
          'can collapse suddenly in hot weather.',
      symptoms: [
        'Tiger-stripe pattern between leaf veins, yellow or red on dark',
        'Small dark spots on berries, sometimes cracking',
        'Sudden wilting and death of a whole arm or vine in summer',
        'Dark streaking or soft rot in the trunk when cut',
      ],
      organicTreatment: [
        'Cut out affected arms well into clean wood',
        'Remove and burn dead vines — they seed the rest of the block',
        'Delay pruning until late dormancy to reduce infection of cuts',
      ],
      chemicalTreatment: [
        'No effective curative treatment exists',
        'Protect large pruning wounds with a registered sealant or paste',
      ],
      prevention: [
        'Prune late and in dry weather',
        'Make small cuts; avoid large wounds on the trunk',
        'Plant certified clean nursery stock',
      ],
    ),
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)': DiseaseInfo(
      label: 'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
      cropName: 'Grape',
      diseaseName: 'Isariopsis Leaf Spot',
      severity: DiseaseSeverity.moderate,
      description:
          'A leaf-spotting fungus that thrives in warm humid weather. It '
          'attacks foliage rather than fruit, but heavy defoliation leaves '
          'the crop unable to ripen properly.',
      symptoms: [
        'Irregular dark brown to black leaf spots',
        'Spots merging into large blighted areas',
        'Yellowing around the lesions',
        'Early leaf drop from the base of the shoot upward',
      ],
      organicTreatment: [
        'Remove and destroy fallen infected leaves',
        'Copper-based sprays during humid spells',
        'Thin the canopy to speed drying',
      ],
      chemicalTreatment: [
        'Mancozeb or a strobilurin fungicide',
        'Begin when spots first appear and repeat per label',
      ],
      prevention: [
        'Open canopy management and leaf removal in the fruit zone',
        'Avoid overhead irrigation',
        'Clear leaf litter at the end of the season',
      ],
    ),
    'Grape___healthy': DiseaseInfo(
      label: 'Grape___healthy',
      cropName: 'Grape',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Keep the fruit zone open so bunches dry quickly',
        'Remove mummified berries during dormant pruning',
        'Scout from bloom to bunch closure — the highest-risk window',
      ],
    ),

    // ---------------------------------------------------------------- Orange
    'Orange___Haunglongbing_(Citrus_greening)': DiseaseInfo(
      label: 'Orange___Haunglongbing_(Citrus_greening)',
      cropName: 'Orange',
      diseaseName: 'Huanglongbing (Citrus Greening)',
      severity: DiseaseSeverity.high,
      description:
          'The most serious citrus disease in the world. A bacterium spread '
          'by the citrus psyllid insect. There is no cure — infected trees '
          'decline and die, so control means controlling the insect and '
          'removing infected trees before they infect others.',
      symptoms: [
        'Blotchy mottle — yellowing that is asymmetric across the leaf midrib',
        'Leaves with corky, enlarged veins',
        'Small lopsided fruit that stays green at the bottom end',
        'Bitter fruit and heavy premature fruit drop',
        'Twig dieback and thinning canopy',
      ],
      organicTreatment: [
        'Remove and destroy infected trees promptly — they are a source for '
            'the whole orchard',
        'Encourage natural psyllid enemies such as ladybirds and lacewings',
        'Reflective mulch to deter psyllids from young flush',
      ],
      chemicalTreatment: [
        'No cure for the tree itself',
        'Control citrus psyllid with registered insecticides, especially on '
            'new flush when psyllids feed and breed',
        'Coordinate timing with neighbouring farms — isolated spraying fails',
      ],
      prevention: [
        'Plant only certified disease-free nursery stock',
        'Inspect new flush for psyllids regularly',
        'Report suspected cases to your extension officer — this is a '
            'notifiable disease in many countries',
      ],
    ),

    // ----------------------------------------------------------------- Peach
    'Peach___Bacterial_spot': DiseaseInfo(
      label: 'Peach___Bacterial_spot',
      cropName: 'Peach',
      diseaseName: 'Bacterial Spot',
      severity: DiseaseSeverity.moderate,
      description:
          'A bacterium (Xanthomonas arboricola) spread by wind-driven rain. '
          'Copper helps but cannot be sprayed heavily on peach foliage '
          'without burning it, so variety choice does most of the work.',
      symptoms: [
        'Small angular purple-black leaf spots',
        'Spot centres dropping out, leaving a shot-hole appearance',
        'Heavy leaf yellowing and drop',
        'Sunken pitted lesions and cracking on fruit',
      ],
      organicTreatment: [
        'Low-rate copper at dormancy and leaf fall only',
        'Prune to improve airflow',
        'Remove severely infected shoots',
      ],
      chemicalTreatment: [
        'Oxytetracycline during the growing season where registered',
        'Low-rate copper — full rates cause phytotoxicity on peach',
      ],
      prevention: [
        'Plant resistant cultivars — the single most effective measure',
        'Shelter from prevailing wind, which drives the bacteria into leaves',
        'Avoid overhead irrigation',
      ],
    ),
    'Peach___healthy': DiseaseInfo(
      label: 'Peach___healthy',
      cropName: 'Peach',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Prune annually for airflow and light',
        'Clear fallen leaves and fruit mummies',
        'Watch for leaf curl at bud swell in cool wet springs',
      ],
    ),

    // ------------------------------------------------------------- Raspberry
    'Raspberry___healthy': DiseaseInfo(
      label: 'Raspberry___healthy',
      cropName: 'Raspberry',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Remove spent floricanes after harvest',
        'Keep rows narrow so air moves through',
        'Drip irrigate rather than overhead',
      ],
    ),

    // --------------------------------------------------------------- Soybean
    'Soybean___healthy': DiseaseInfo(
      label: 'Soybean___healthy',
      cropName: 'Soybean',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Rotate out of soybean to break rust and cyst nematode cycles',
        'Scout the lower canopy — rust starts there and moves up',
        'Use certified, treated seed',
      ],
    ),

    // ------------------------------------------------------------ Strawberry
    'Strawberry___Leaf_scorch': DiseaseInfo(
      label: 'Strawberry___Leaf_scorch',
      cropName: 'Strawberry',
      diseaseName: 'Leaf Scorch',
      severity: DiseaseSeverity.moderate,
      description:
          'A fungus (Diplocarpon earlianum) that builds up in crowded, damp '
          'beds. It weakens the plant and cuts next season\'s yield rather '
          'than destroying the current crop outright.',
      symptoms: [
        'Many small dark purple spots on the upper leaf surface',
        'Spots merging until the leaf looks scorched and dry',
        'Leaf margins curling upward',
        'Reddish-purple blotching on petioles and runners',
      ],
      organicTreatment: [
        'Remove and destroy infected leaves after harvest',
        'Renovate beds — mow old foliage and thin crowded plants',
        'Copper or sulphur sprays on new growth',
      ],
      chemicalTreatment: [
        'Captan or myclobutanil per label',
        'Apply after renovation when new leaves emerge',
      ],
      prevention: [
        'Wide spacing and narrow rows',
        'Drip irrigation, never overhead',
        'Plant resistant cultivars and certified runners',
        'Renovate beds every year after harvest',
      ],
    ),
    'Strawberry___healthy': DiseaseInfo(
      label: 'Strawberry___healthy',
      cropName: 'Strawberry',
      diseaseName: 'Healthy',
      severity: DiseaseSeverity.healthy,
      description: 'No disease detected. The foliage looks healthy.',
      symptoms: [],
      organicTreatment: [],
      chemicalTreatment: [],
      prevention: [
        'Straw mulch keeps fruit off the soil and cuts rot',
        'Thin runners to stop the bed crowding',
        'Renovate after harvest each year',
      ],
    ),
  };

  /// Resolves a raw model label to treatment knowledge, falling back to a
  /// parsed placeholder when the class is not in the map.
  static DiseaseInfo lookup(String label) =>
      _byLabel[label] ?? DiseaseInfo.unknown(label);

  static int get knownCount => _byLabel.length;
}
