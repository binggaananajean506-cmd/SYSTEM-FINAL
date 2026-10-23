import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum BariliDestinationCategory {
  nature('Nature', Icons.waterfall_chart_rounded),
  beaches('Beaches', Icons.beach_access_rounded),
  food('Food & Dining', Icons.restaurant_rounded),
  culture('Heritage & Local Life', Icons.account_balance_rounded),
  activities('Activities', Icons.directions_bike_rounded),
  stays('Stays', Icons.hotel_rounded);

  const BariliDestinationCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

class BariliDestinationPhoto {
  const BariliDestinationPhoto.asset({
    required String path,
    required this.credit,
    required this.sourceUrl,
  }) : assetPath = path,
       networkUrl = null;

  const BariliDestinationPhoto.network({
    required String url,
    required this.credit,
    required this.sourceUrl,
  }) : networkUrl = url,
       assetPath = null;

  final String? assetPath;
  final String? networkUrl;
  final String credit;
  final String sourceUrl;
}

/// The single curated place record consumed by Explore, local search, details,
/// and the resident map. Optional facts are deliberately omitted when they
/// could not be verified from a current source.
class BariliDestination {
  const BariliDestination({
    required this.id,
    required this.name,
    required this.category,
    required this.barangay,
    required this.addressText,
    required this.summary,
    required this.description,
    required this.visitNote,
    required this.position,
    required this.tags,
    required this.photos,
    required this.informationSourceLabel,
    required this.informationSourceUrl,
    this.featured = false,
    this.mapVisible = true,
  });

  final String id;
  final String name;
  final BariliDestinationCategory category;
  final String barangay;
  final String addressText;
  final String summary;
  final String description;
  final String visitNote;
  final LatLng position;
  final List<String> tags;
  final List<BariliDestinationPhoto> photos;
  final String informationSourceLabel;
  final String informationSourceUrl;
  final bool featured;
  final bool mapVisible;

  String get searchableText => <String>[
    name,
    category.label,
    barangay,
    addressText,
    summary,
    description,
    ...tags,
  ].join(' ').toLowerCase();
}

/// Curated records are limited to places with a verifiable map, government,
/// tourism, business, or active booking source. Coordinates come from the
/// linked map record (or its mapped venue) and were checked against the bundled
/// PSA/GeoRisk Barili barangay polygons. No ratings, prices, or hours are
/// stored because those details change frequently.
const List<BariliDestination> bariliDestinations = [
  BariliDestination(
    id: 'mantayupan-falls',
    name: 'Mantayupan Falls',
    category: BariliDestinationCategory.nature,
    barangay: 'Campangga',
    addressText: 'Campangga, Barili, Cebu, Philippines',
    summary: 'Barili\'s landmark two-tier waterfall and forest swimming stop.',
    description:
        'Mantayupan Falls is a well-known natural attraction in Barili. The mapped entrance and cascade are reached from the Mantayupan road area in Barangay Campangga.',
    visitNote:
        'Conditions, fees, and swimming access can change after heavy rain. Confirm locally before visiting.',
    position: LatLng(10.1009225, 123.5357685),
    tags: ['waterfall', 'swimming', 'outdoors', 'eco-tourism'],
    photos: [
      BariliDestinationPhoto.asset(
        path: 'assets/images/resident_dashboard/mantayupanfalls.png',
        credit: 'E-SUGID local media',
        sourceUrl: 'https://www.cebu.gov.ph/about/',
      ),
      BariliDestinationPhoto.network(
        url:
            'https://commons.wikimedia.org/wiki/Special:Redirect/file/Mantayupan%20Falls%20of%20Barili,%20Cebu.jpg?width=1400',
        credit: 'Wikimedia Commons contributor',
        sourceUrl:
            'https://commons.wikimedia.org/wiki/File:Mantayupan_Falls_of_Barili,_Cebu.jpg',
      ),
    ],
    informationSourceLabel: 'Province of Cebu',
    informationSourceUrl: 'https://www.cebu.gov.ph/about/',
    featured: true,
  ),
  BariliDestination(
    id: 'bolocboloc-spring',
    name: 'Bolocboloc Sulfuric Spring',
    category: BariliDestinationCategory.nature,
    barangay: 'Bolocboloc',
    addressText: 'Bolocboloc, Barili, Cebu, Philippines',
    summary: 'A locally recognized spring destination in Barangay Bolocboloc.',
    description:
        'Bolocboloc Sulfuric Spring is an inland recreation site identified in government tourism-access records for Barili.',
    visitNote:
        'Confirm current access and water conditions with the barangay before making a special trip.',
    position: LatLng(10.114110, 123.529785),
    tags: ['spring', 'pool', 'nature', 'swimming'],
    photos: [],
    informationSourceLabel: 'Official Gazette / DPWH',
    informationSourceUrl:
        'https://www.dbm.gov.ph/wp-content/uploads/GAA/GAA2018/VolumeI/DETAILSDPWH.pdf',
  ),
  BariliDestination(
    id: 'sayaw-beach',
    name: 'Sayaw Beach',
    category: BariliDestinationCategory.beaches,
    barangay: 'Sayaw',
    addressText: 'Sayaw, Barili, Cebu, Philippines',
    summary:
        'A mapped coastal beach and long-established Barili day-trip stop.',
    description:
        'Sayaw Beach is one of Barili\'s best-known seaside destinations, valued for its coastline and views across the Tañon Strait.',
    visitNote:
        'Sea conditions and access arrangements vary. Confirm locally before swimming or arranging a boat trip.',
    position: LatLng(10.1150285, 123.4809599),
    tags: ['beach', 'coast', 'swimming', 'sea', 'Sayaw'],
    photos: [
      BariliDestinationPhoto.network(
        url:
            'https://ak-d.tripcdn.com/images/1mi0k224x8ub91nbv10E1_R_600_400_R5_Q90.jpg?proc=source%2Ftrip',
        credit: 'Trip.com community photo',
        sourceUrl: 'https://www.trip.com/moments/detail/cebu-534-120516040/',
      ),
    ],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/relation/5522338',
    featured: true,
  ),
  BariliDestination(
    id: 'anahaw-beach-resort',
    name: 'Anahaw Beach Resort',
    category: BariliDestinationCategory.beaches,
    barangay: 'Japitan',
    addressText: 'Sitio Cabacongan, Japitan, Barili, Cebu, Philippines',
    summary: 'A beach destination on Barili\'s Japitan coast.',
    description:
        'Anahaw Beach Resort is a coastal leisure destination in Sitio Cabacongan, Barangay Japitan, also identified by its former Sanraka Beach name.',
    visitNote:
        'Contact the property before travelling because access and guest arrangements may change.',
    position: LatLng(10.1309881, 123.4983810),
    tags: ['beach', 'coast', 'Japitan', 'Sanraka'],
    photos: [],
    informationSourceLabel: 'Sugbo.ph destination guide',
    informationSourceUrl: 'https://sugbo.ph/2024/50-destinations-in-sugbo/',
  ),
  BariliDestination(
    id: 'estino-milk-station',
    name: 'Estino Milk Station',
    category: BariliDestinationCategory.food,
    barangay: 'Dakit',
    addressText: 'Dakit, Barili, Cebu, Philippines',
    summary:
        'A mapped roadside stop for local dairy products and refreshments.',
    description:
        'Estino Milk Station is a Barili stopover listed on current map data as a café in Barangay Dakit.',
    visitNote: 'Product availability and opening times can change.',
    position: LatLng(10.1143024, 123.5607156),
    tags: ['milk', 'ice cream', 'cafe', 'dairy', 'stopover'],
    photos: [],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/node/8493775918',
  ),
  BariliDestination(
    id: 'shamrock-barili',
    name: 'Shamrock Barili',
    category: BariliDestinationCategory.food,
    barangay: 'Poblacion',
    addressText: 'Poblacion, Barili, Cebu, Philippines',
    summary: 'A Barili branch and traveler stop for Cebuano delicacies.',
    description:
        'The Barili Shamrock location is a mapped food and lodging stop associated with the Cebuano delicacy brand.',
    visitNote: 'Stock, dining service, and opening times can change.',
    position: LatLng(10.1162787, 123.5076884),
    tags: ['pasalubong', 'otap', 'delicacies', 'restaurant', 'Poblacion'],
    photos: [
      BariliDestinationPhoto.network(
        url:
            'https://shamrockotap.com/wp-content/uploads/2021/01/Shamrock0360-400x284.jpg',
        credit: 'Shamrock official website',
        sourceUrl: 'https://shamrockotap.com/',
      ),
    ],
    informationSourceLabel: 'Shamrock official website',
    informationSourceUrl: 'https://shamrockotap.com/',
  ),
  BariliDestination(
    id: 'chip-in-restaurant',
    name: 'Chip-in Restaurant and Karaoke',
    category: BariliDestinationCategory.food,
    barangay: 'Poblacion',
    addressText: 'Poblacion, Barili, Cebu, Philippines',
    summary: 'A mapped local restaurant in central Barili.',
    description:
        'Chip-in Restaurant and Karaoke is listed on OpenStreetMap as a restaurant in Barili\'s Poblacion area.',
    visitNote: 'Confirm current opening times directly with the venue.',
    position: LatLng(10.1133111, 123.5097498),
    tags: ['restaurant', 'karaoke', 'local food', 'Poblacion'],
    photos: [],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/node/9250382457',
  ),
  BariliDestination(
    id: 'st-anne-shrine',
    name: 'Archdiocesan Shrine of St. Anne',
    category: BariliDestinationCategory.culture,
    barangay: 'Poblacion',
    addressText: 'Poblacion, Barili, Cebu, Philippines',
    summary: 'Barili\'s historic active parish church and town landmark.',
    description:
        'Also known as Barili Church or Sta. Ana Church, this active parish and archdiocesan shrine is a central heritage landmark in Poblacion.',
    visitNote:
        'This is an active place of worship. Dress respectfully and avoid disrupting services.',
    position: LatLng(10.1112404, 123.5112960),
    tags: ['church', 'Sta Ana', 'Saint Anne', 'heritage', 'Poblacion'],
    photos: [
      BariliDestinationPhoto.asset(
        path: 'assets/images/resident_dashboard/santa-ana.png',
        credit: 'E-SUGID local media',
        sourceUrl:
            'https://commons.wikimedia.org/wiki/Category:Saint_Anne_Parish_Church_(Barili)',
      ),
      BariliDestinationPhoto.network(
        url:
            'https://commons.wikimedia.org/wiki/Special:Redirect/file/Barili%20Church.jpg?width=1400',
        credit: 'Elmer B. Domingo / Wikimedia Commons (CC BY-SA 4.0)',
        sourceUrl: 'https://commons.wikimedia.org/wiki/File:Barili_Church.jpg',
      ),
    ],
    informationSourceLabel: 'Wikimedia Commons',
    informationSourceUrl:
        'https://commons.wikimedia.org/wiki/Category:Saint_Anne_Parish_Church_(Barili)',
    featured: true,
  ),
  BariliDestination(
    id: 'barili-public-market',
    name: 'Barili Public Market',
    category: BariliDestinationCategory.culture,
    barangay: 'Poblacion',
    addressText: 'Poblacion, Barili, Cebu, Philippines',
    summary: 'The mapped municipal marketplace for everyday local trade.',
    description:
        'Barili Public Market is a central Poblacion marketplace and a practical stop for seeing and supporting everyday local commerce.',
    visitNote: 'Vendor availability varies by day and time.',
    position: LatLng(10.1120418, 123.5124287),
    tags: ['market', 'produce', 'local experience', 'Poblacion'],
    photos: [],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/way/402325643',
  ),
  BariliDestination(
    id: 'barili-municipal-hall',
    name: 'Barili Municipal Hall',
    category: BariliDestinationCategory.culture,
    barangay: 'Poblacion',
    addressText: 'Carcar–Barili Road, Poblacion, Barili, Cebu, Philippines',
    summary: 'The municipal government landmark in central Barili.',
    description:
        'Barili Municipal Hall is the mapped seat of the municipal government and a civic landmark in Poblacion.',
    visitNote:
        'Government office access follows official working arrangements.',
    position: LatLng(10.1163562, 123.5097591),
    tags: ['municipal hall', 'government', 'civic', 'Poblacion'],
    photos: [],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/way/402325216',
  ),
  BariliDestination(
    id: 'ac-tilapia-fun-fishing',
    name: 'AC Tilapia Fun Fishing & Family Park',
    category: BariliDestinationCategory.activities,
    barangay: 'Campangga',
    addressText: 'Campangga, Barili, Cebu, Philippines',
    summary:
        'A mapped fishing and family recreation destination near the falls.',
    description:
        'AC Tilapia Fun Fishing & Family Park is a locally recorded fishing destination near Mantayupan Falls in Barangay Campangga.',
    visitNote: 'Confirm current activities and access before travelling.',
    position: LatLng(10.1026045, 123.5322866),
    tags: ['fishing', 'family park', 'pond', 'Campangga'],
    photos: [],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/way/402324714',
  ),
  BariliDestination(
    id: 'barili-atv-adventure',
    name: 'Barili ATV Adventure',
    category: BariliDestinationCategory.activities,
    barangay: 'Nasipit',
    addressText: 'Nasipit, Barili, Cebu, Philippines',
    summary: 'A mapped off-road activity venue in Barangay Nasipit.',
    description:
        'Barili ATV Adventure offers guided off-road routes through Barili terrain and was launched as part of the municipality\'s tourism reopening.',
    visitNote:
        'Book or confirm availability directly; routes may be affected by weather.',
    position: LatLng(10.1129212, 123.5441708),
    tags: ['ATV', 'off-road', 'adventure', 'Nasipit'],
    photos: [],
    informationSourceLabel: 'The Freeman',
    informationSourceUrl:
        'https://www.philstar.com/the-freeman/cebu-news/2020/08/03/2032556/atv-adventure-opens-barili',
    featured: true,
  ),
  BariliDestination(
    id: 'barili-sports-center',
    name: 'Elissa Paras Vergara Memorial Sports Center',
    category: BariliDestinationCategory.activities,
    barangay: 'Campangga',
    addressText: 'Campangga, Barili, Cebu, Philippines',
    summary: 'A mapped public sports facility in Barangay Campangga.',
    description:
        'The Elissa Paras Vergara Memorial Sports Center is a local sports facility recorded on OpenStreetMap.',
    visitNote: 'Public access may depend on scheduled activities or events.',
    position: LatLng(10.1040208, 123.5280657),
    tags: ['sports', 'recreation', 'community', 'Campangga'],
    photos: [],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/way/1126827981',
  ),
  BariliDestination(
    id: 'bellissimo-minolos',
    name: 'Bellissimo Minolos',
    category: BariliDestinationCategory.stays,
    barangay: 'Minolos',
    addressText: 'Minolos, Barili, Cebu, Philippines',
    summary: 'A currently bookable coastal resort in Barangay Minolos.',
    description:
        'Bellissimo Minolos is a resort accommodation with a restaurant and coastal leisure facilities, listed on its official site and active booking services.',
    visitNote: 'Check the official property site for current availability.',
    position: LatLng(10.1056586, 123.4730257),
    tags: ['resort', 'hotel', 'beach', 'accommodation', 'Minolos'],
    photos: [],
    informationSourceLabel: 'Bellissimo Minolos official website',
    informationSourceUrl: 'https://bellissimominolos.com/',
  ),
  BariliDestination(
    id: 'bluespace-mountain-resort',
    name: 'BlueSpace Mountain Resort',
    category: BariliDestinationCategory.stays,
    barangay: 'Mayana',
    addressText: 'Mayana, Barili, Cebu, Philippines',
    summary: 'A mapped mountain resort in Barangay Mayana.',
    description:
        'BlueSpace Mountain Resort is a recorded inland tourism establishment in the upland Barangay Mayana area of Barili.',
    visitNote:
        'Confirm current booking and access arrangements before travelling.',
    position: LatLng(10.0817734, 123.5627527),
    tags: ['mountain', 'resort', 'stay', 'Mayana'],
    photos: [],
    informationSourceLabel: 'OpenStreetMap',
    informationSourceUrl: 'https://www.openstreetmap.org/node/9909753725',
  ),
  BariliDestination(
    id: 'cocina-1914',
    name: 'Cocina 1914',
    category: BariliDestinationCategory.food,
    barangay: 'Poblacion',
    addressText: 'Poblacion, Barili, Cebu, Philippines',
    summary:
        'A restored 1914 colonial home offering authentic Cebuano heritage dining.',
    description:
        'Cocina 1914, situated within the historic Tomas Delgado Ancestral Home, provides a cultural culinary experience featuring authentic Cebuano recipes inside a preserved early-20th-century residence.',
    visitNote:
        'Prior table reservations or checking daily opening hours is recommended for group dining.',
    position: LatLng(10.113600, 123.510800),
    tags: ['restaurant', 'heritage dining', 'ancestral house', 'Poblacion', 'food', 'local cuisine'],
    photos: [],
    informationSourceLabel: 'Barili Tourism & Heritage Guide',
    informationSourceUrl: 'https://www.facebook.com/cocina1914',
    featured: true,
  ),
  BariliDestination(
    id: 'casa-panares',
    name: 'Casa Pañares',
    category: BariliDestinationCategory.culture,
    barangay: 'Poblacion',
    addressText: 'Poblacion, Barili, Cebu, Philippines',
    summary:
        'A landmark 1878 ancestral home featuring historic coral stone walls and capiz windows.',
    description:
        'Built in the late 19th century, Casa Pañares is one of Barili\'s oldest surviving heritage structures, characterized by sturdy coral masonry ground floors and classic wooden upper quarters.',
    visitNote:
        'This is a private heritage residence; visitors are requested to admire respectfully from the street or request permission before entry.',
    position: LatLng(10.112800, 123.511500),
    tags: ['ancestral house', 'heritage', 'history', 'architecture', 'Poblacion', 'Spanish era'],
    photos: [],
    informationSourceLabel: 'Barili Cultural Heritage Registry',
    informationSourceUrl: 'https://e.gov.ph',
    featured: true,
  ),
  BariliDestination(
    id: 'molave-milk-station',
    name: 'Molave Milk Station',
    category: BariliDestinationCategory.food,
    barangay: 'Dakit',
    addressText: 'Natalio Bacalso South National Highway, Dakit, Barili, Cebu, Philippines',
    summary:
        'Famous South Cebu roadside stopover for fresh dairy, yogurt, and artisanal ice cream.',
    description:
        'The Molave Milk Station in Barangay Dakit is an iconic travel stopover along the southern highway, celebrated for its freshly produced cow and carabao milk, pastillas, cheese, and refreshing ice creams.',
    visitNote:
        'Popular stopover on weekend mornings; best visited early for complete dairy product availability.',
    position: LatLng(10.1143024, 123.5607156),
    tags: ['milk station', 'dairy', 'ice cream', 'stopover', 'Dakit', 'highway', 'snacks'],
    photos: [],
    informationSourceLabel: 'Province of Cebu Tourism',
    informationSourceUrl: 'https://www.cebu.gov.ph',
    featured: true,
  ),
  BariliDestination(
    id: 'cafe-alfonso',
    name: 'Café Alfonso',
    category: BariliDestinationCategory.food,
    barangay: 'Nasipit',
    addressText: 'Nasipit, Barili, Cebu, Philippines',
    summary:
        'A beloved local cafe in Nasipit renowned for dimsum, comfort snacks, and brewed coffee.',
    description:
        'Café Alfonso is a prominent local dining and meeting spot in Barangay Nasipit, known for delicious handmade dimsum, rice bowls, signature coolers, and a welcoming community ambiance.',
    visitNote:
        'Great stop for lunch, afternoon snacks, or resting before or after outdoor adventures.',
    position: LatLng(10.113500, 123.542200),
    tags: ['cafe', 'dimsum', 'coffee', 'snacks', 'Nasipit', 'dining'],
    photos: [],
    informationSourceLabel: 'Local Business Directory',
    informationSourceUrl: 'https://www.facebook.com',
    featured: false,
  ),
  BariliDestination(
    id: 'fats-aquapark',
    name: 'Fat’s Aquapark Resort',
    category: BariliDestinationCategory.stays,
    barangay: 'Minolos',
    addressText: 'Minolos, Barili, Cebu, Philippines',
    summary:
        'Unique coastal leisure resort with cottages built over the sea connected by wooden boardwalks.',
    description:
        'Fat\'s Aquapark Resort in Barangay Minolos offers seaside stilt cottages, overwater boardwalks, and direct sea access overlooking the Tañon Strait, perfect for family getaways and day picnics.',
    visitNote:
        'Cottages and boat rides depend on tidal and weather conditions. Advance booking is advised.',
    position: LatLng(10.108200, 123.475500),
    tags: ['aquapark', 'resort', 'overwater', 'cottages', 'swimming', 'Minolos', 'stay'],
    photos: [],
    informationSourceLabel: 'Barili Coastal Tourism',
    informationSourceUrl: 'https://www.facebook.com',
    featured: true,
  ),
];
