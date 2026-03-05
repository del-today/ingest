-- post-build.sql
-- Runs after build.py loads events.db
-- Applies quality filters, type corrections, and neighbourhood tags

-- ============================================================
-- LOW QUALITY: Generic spam/dating/low-effort organizers
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LOW-QUALITY'))
WHERE
  -- Silly dating events
  event_json ->> '$.organizer.name' LIKE '%your dream partner%'
  OR event_json ->> '$.organizer.name' LIKE '%vinit kotadiya%'
  OR event_json ->> '$.organizer.name' LIKE '%rashid mubarak nadaf%'
  -- Coworking is not an event
  OR event_json ->> '$.name' LIKE '%Co-Working%'
  -- Rage rooms
  OR url LIKE '%rage-room%';


-- ============================================================
-- LOW QUALITY: Free DJ/Bollywood nights on HighApe
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LOW-QUALITY'))
WHERE
  event_json ->> '$.keywords' LIKE '%"highape"%'
  AND event_json ->> '$.keywords' LIKE '%"free entry"%'
  AND (
    event_json ->> '$.keywords' LIKE '%bollywood night%'
    OR event_json ->> '$.keywords' LIKE '%dj night%'
    OR event_json ->> '$.keywords' LIKE '%commercial music%'
    OR event_json ->> '$.keywords' LIKE '%karaoke night%'
  );


-- ============================================================
-- LOW QUALITY: Theme/water/snow parks, game zones on District
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LOW-QUALITY'))
WHERE url LIKE '%district.in%'
  AND (
    event_json->>'$.keywords' LIKE '%theme park%'
    OR event_json->>'$.keywords' LIKE '%snow park%'
    OR event_json->>'$.keywords' LIKE '%water park%'
    OR event_json->>'$.keywords' LIKE '%Game Zones%'
    OR event_json->>'$.keywords' LIKE '%Go Karting%'
    OR event_json->>'$.keywords' LIKE '%Arcades%'
    OR event_json->>'$.keywords' LIKE '%Escape Room%'
    OR event_json->>'$.keywords' LIKE '%Trampoline Parks%'
    OR event_json->>'$.keywords' LIKE '%Shooting Range%'
  );


-- ============================================================
-- LOW QUALITY: Regular clubbing nights
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LOW-QUALITY'))
WHERE
  event_json ->> '$.name' LIKE '%ladies night%'
  OR event_json ->> '$.keywords' LIKE '%ladies night%'
  OR event_json ->> '$.description' LIKE '%ladies night%'
  OR event_json ->> '$.description' LIKE '%dj night%'
  OR event_json ->> '$.description' LIKE '%ladies & models night%'
  OR event_json ->> '$.name' LIKE '%ladies thursday%'
  OR event_json ->> '$.name' LIKE '%bollywood night%'
  OR event_json ->> '$.keywords' LIKE '%bollywood night%'
  OR event_json ->> '$.keywords' LIKE '%techno%'
  OR event_json ->> '$.name' LIKE '%bollywood bash%'
  OR event_json ->> '$.name' LIKE '%pub crawl%'
  OR event_json ->> '$.name' LIKE '%monsoon monday%'
  OR event_json ->> '$.name' LIKE '%rock bottom monday%'
  OR event_json ->> '$.name' LIKE '%episode monday%'
  OR event_json ->> '$.name' LIKE '%worth it monday%'
  OR event_json ->> '$.name' LIKE '%tashan tuesday%'
  OR event_json ->> '$.name' LIKE '%tashn tuesday%'
  OR event_json ->> '$.name' LIKE '%tease tuesday%'
  OR event_json ->> '$.name' LIKE '%mix bag wednesday%'
  OR event_json ->> '$.name' LIKE '%mixbag wednesday%'
  OR event_json ->> '$.name' LIKE '%tgif friday%'
  OR event_json ->> '$.name' LIKE '%techno terrace%'
  -- Stranger meets
  OR url LIKE '%tuesday-lets-party%'
  OR url LIKE '%dinner-with-strangers%'
  OR event_json->>'$.organizer.name' = 'VOYAGIO';


-- ============================================================
-- LOW QUALITY: Multi-day duplicate listings
-- (venues that list each day of a multi-day event separately)
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LOW-QUALITY'))
WHERE
  substr(event_json ->> '$.startDate', 0, 10) != substr(event_json ->> '$.endDate', 0, 10)
  AND event_json ->> '$.keywords' LIKE '%"ALLEVENTS"%';


-- ============================================================
-- LOW QUALITY: Social Mixers on District
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LOW-QUALITY'))
WHERE
  url LIKE '%district.in%'
  AND event_json ->> '$.keywords' LIKE '%Social Mixers%';


-- ============================================================
-- LOW QUALITY: Hobby workshops from AllEvents
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LOW-QUALITY'))
WHERE event_json->>'$.keywords' LIKE '%ALLEVENTS%'
  AND (
    lower(event_json->>'$.name') LIKE '%pottery%'
    OR lower(event_json->>'$.name') LIKE '%resin art%'
    OR lower(event_json->>'$.name') LIKE '%candle making%'
    OR lower(event_json->>'$.name') LIKE '%soap making%'
    OR lower(event_json->>'$.name') LIKE '%crochet%'
    OR lower(event_json->>'$.name') LIKE '%sushi making%'
    OR lower(event_json->>'$.name') LIKE '%perfumery%'
    OR lower(event_json->>'$.name') LIKE '%fluid art%'
    OR lower(event_json->>'$.name') LIKE '%macrame%'
    OR lower(event_json->>'$.name') LIKE '%terrarium%'
    OR lower(event_json->>'$.name') LIKE '%pizza making%'
    OR lower(event_json->>'$.name') LIKE '%kawaii%'
    OR lower(event_json->>'$.name') LIKE '%laughter therapy%'
    OR lower(event_json->>'$.name') LIKE '%real estate%'
    OR lower(event_json->>'$.name') LIKE '%wedding exhibition%'
    OR lower(event_json->>'$.name') LIKE '%scholarship orientation%'
    OR lower(event_json->>'$.name') LIKE '%make your own%'
    OR lower(event_json->>'$.name') LIKE '%art of baking%'
  );


-- ============================================================
-- BUSINESS: Networking, real estate, education consulting
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'BUSINESS'))
WHERE
  lower(event_json ->> '$.organizer.name') IN (
    'address advisors',
    'adamant ventures',
    'indian school of business',
    'invest in the usa (iiusa)',
    'india international travel mart',
    'hj real estates',
    'access mba',
    'trescon sd',
    'adrez advisors private limited',
    'brandland advertising pvt ltd',
    'brightside online solutions',
    'dtorr',
    'global tree careers private limited',
    'global tree',
    'walnut knowledge solutions private limited',
    'z p enterprises',
    'upgrad abroad',
    'charista foundation',
    'etg career labs private limited',
    'startup synerz',
    'startupparty',
    'institute of product leadership (adaptive marketing solutions pvt ltd)',
    'seed global education'
  )
  OR (
    url LIKE '%network-meetup%'
    OR url LIKE '%networking-meetup%'
    OR url LIKE '%networking-meet%'
    OR url LIKE '%business-networking%'
    OR url LIKE '%virtual-hackathon%'
    OR url LIKE '%founders-investors%'
    OR url LIKE '%property-expo%'
    OR url LIKE '%agentic-ai%'
    OR url LIKE '%ai-workshop%'
    OR url LIKE '%ai-master%'
    OR url LIKE '%entrepreneur-forum%'
    OR url LIKE '%-founders-%'
    OR url LIKE '%startups-club%'
    OR event_json ->> '$.keywords' LIKE '%Conference%'
  );


-- ============================================================
-- WOOWOO: Pseudoscience and wellness woo
-- https://rationalwiki.org/wiki/Woo
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'WOOWOO'))
WHERE
  event_json ->> '$.name' LIKE '%QI Gong%'
  OR event_json ->> '$.name' LIKE '%tarot %'
  OR event_json ->> '$.name' LIKE '%Sound Immersion%'
  OR event_json ->> '$.name' LIKE '%sound bath%'
  OR event_json ->> '$.url'  LIKE '%sound-bath%'
  OR event_json ->> '$.name' LIKE '%sound healing%'
  OR event_json ->> '$.description' LIKE '%sound healing%'
  OR event_json ->> '$.description' LIKE '%pranic heal%'
  OR event_json ->> '$.name' LIKE '%Breathwork%'
  OR event_json ->> '$.name' LIKE '%SoundBath%'
  OR event_json ->> '$.name' LIKE '%ayurvedic workshop%'
  OR event_json ->> '$.name' LIKE '%voice activation%'
  OR event_json ->> '$.description' LIKE '%qi gong%'
  OR event_json ->> '$.description' LIKE '%crystal healing%'
  OR event_json ->> '$.name' LIKE '%soul meridian%'
  OR event_json ->> '$.name' LIKE '%iskcon%'
  OR lower(event_json ->> '$.organizer.name') IN (
    'the audacious movement',
    'new acropolis'
  );


-- ============================================================
-- NOTINDEL: Treks, camping, out-of-city trips
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'NOTINDEL'))
WHERE
  url LIKE '%-trek%'
  OR url LIKE '%camping%'
  OR url LIKE '%weekend-getaway%'
  OR url LIKE '%-shimla%'
  OR url LIKE '%-manali%'
  OR url LIKE '%-rishikesh%'
  OR url LIKE '%-mussoorie%'
  OR url LIKE '%-corbett%'
  OR url LIKE '%-nainital%'
  OR event_json ->> '$.organizer.name' LIKE 'my hikes%'
  OR event_json ->> '$.organizer.name' LIKE '%tripper trails%'
  OR event_json ->> '$.organizer.name' LIKE '%tripbae%'
  OR event_json ->> '$.organizer.name' LIKE '%namma trip%'
  -- All Travel/camping events on HighApe
  OR (
    (
      event_json ->> '$.keywords' LIKE '%"travel"%'
      OR event_json ->> '$.keywords' LIKE '%"camping"%'
    )
    AND event_json ->> '$.keywords' LIKE '%"HIGHAPE"%'
  )
  -- District camping/trip events
  OR (
    url LIKE '%district.in%'
    AND (
      event_json->>'$.keywords' LIKE '%camping%'
      OR event_json->>'$.keywords' LIKE '%trip%'
    )
  );


-- ============================================================
-- NOTINDEL: Events in other Indian cities
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'NOTINDEL'))
WHERE
  event_json -> '$.keywords' NOT LIKE '%NOTINDEL%'
  AND (
    event_json ->> '$.location' LIKE '%Mumbai%'
    OR event_json ->> '$.location' LIKE '%Bangalore%'
    OR event_json ->> '$.location' LIKE '%Bengaluru%'
    OR event_json ->> '$.location' LIKE '%Hyderabad%'
    OR event_json ->> '$.location' LIKE '%Ahmedabad%'
    OR event_json ->> '$.location' LIKE '%Chennai%'
    OR event_json ->> '$.location' LIKE '%Kolkata%'
    OR event_json ->> '$.location' LIKE '%Surat%'
    OR event_json ->> '$.location' LIKE '%Pune%'
    OR event_json ->> '$.location' LIKE '%Jaipur%'
    OR event_json ->> '$.location' LIKE '%Lucknow%'
    OR event_json ->> '$.location' LIKE '%Kanpur%'
    OR event_json ->> '$.location' LIKE '%Nagpur%'
    OR event_json ->> '$.location' LIKE '%Indore%'
    OR event_json ->> '$.location' LIKE '%Thane%'
    OR event_json ->> '$.location' LIKE '%Bhopal%'
    OR event_json ->> '$.location' LIKE '%Visakhapatnam%'
    OR event_json ->> '$.location' LIKE '%Patna%'
    OR event_json ->> '$.location' LIKE '%Vadodara%'
    OR event_json ->> '$.location' LIKE '%Ghaziabad%'
    OR event_json ->> '$.location' LIKE '%Ludhiana%'
    OR event_json ->> '$.location' LIKE '%Agra%'
    OR event_json ->> '$.location' LIKE '%Nashik%'
    OR event_json ->> '$.location' LIKE '%Faridabad%'
    OR event_json ->> '$.location' LIKE '%Meerut%'
    OR event_json ->> '$.location' LIKE '%Rajkot%'
    OR event_json ->> '$.location' LIKE '%Varanasi%'
    OR event_json ->> '$.location' LIKE '%Srinagar%'
    OR event_json ->> '$.location' LIKE '%Aurangabad%'
    OR event_json ->> '$.location' LIKE '%Dhanbad%'
    OR event_json ->> '$.location' LIKE '%Amritsar%'
    OR event_json ->> '$.location' LIKE '%Prayagraj%'
    OR event_json ->> '$.location' LIKE '%Howrah%'
    OR event_json ->> '$.location' LIKE '%Ranchi%'
    OR event_json ->> '$.location' LIKE '%Jabalpur%'
    OR event_json ->> '$.location' LIKE '%Gwalior%'
    OR event_json ->> '$.location' LIKE '%Coimbatore%'
    OR event_json ->> '$.location' LIKE '%Vijayawada%'
    OR event_json ->> '$.location' LIKE '%Jodhpur%'
    OR event_json ->> '$.location' LIKE '%Madurai%'
    OR event_json ->> '$.location' LIKE '%Raipur%'
    OR event_json ->> '$.location' LIKE '%Kota%'
    OR event_json ->> '$.location' LIKE '%Bareilly%'
    OR event_json ->> '$.location' LIKE '%Kochi%'
    OR event_json ->> '$.location' LIKE '%Chandigarh%'
    OR event_json ->> '$.location' LIKE '%Bhubaneswar%'
    OR event_json ->> '$.location' LIKE '%Dehradun%'
  );


-- ============================================================
-- DANDIYA: Too many, tag out
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'DANDIYA'))
WHERE event_json LIKE '%dandiya%';


-- ============================================================
-- SPORTS-SCREENING: IPL, F1, Premier League
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'SPORTS-SCREENING'))
WHERE
  (lower(event_json ->> '$.name') LIKE '%live screening%' AND lower(event_json ->> '$.name') LIKE '%premier league%')
  OR event_json ->> '$.name' LIKE '%live cricket screening%'
  OR event_json ->> '$.name' LIKE '%live ipl%'
  OR event_json ->> '$.name' LIKE '%ipl live%'
  OR event_json ->> '$.name' LIKE '%ipl screening%'
  OR (event_json ->> '$.keywords' LIKE '%screening%' AND event_json->>'$.description' LIKE '%IPL%');

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'SPORTS-SCREENING'))
WHERE (
    event_json ->> '$.name' LIKE '%f1 live%'
    OR event_json ->> '$.name' LIKE '%f1 screening%'
    OR event_json ->> '$.name' LIKE '%formula 1 live%'
    OR event_json ->> '$.name' LIKE '%formula 1 screening%'
    OR event_json ->> '$.keywords' LIKE '%grand prix%'
  )
  AND event_json LIKE '%screening%';


-- ============================================================
-- ONLINE: Zoom/online events
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'ONLINE'))
WHERE
  event_json ->> '$.description' LIKE '%online session%'
  OR event_json ->> '$.description' LIKE '%zoom link%';


-- ============================================================
-- TYPE CORRECTIONS
-- ============================================================

-- Step 1: Reset all allevents.in to Event
-- (allevents incorrectly tags many events as MusicEvent)
UPDATE events
SET event_json = json_replace(event_json, '$.@type', 'Event')
WHERE url LIKE 'https://allevents.in%';

-- Step 2: Re-apply correct types for allevents based on name patterns
-- IMPORTANT: must run AFTER the reset above

UPDATE events
SET event_json = json_replace(event_json, '$.@type', 'ScreeningEvent')
WHERE url LIKE 'https://allevents.in%'
  AND (
    lower(event_json->>'$.name') LIKE '%film festival%'
    OR lower(event_json->>'$.name') LIKE '% screening%'
  );

UPDATE events
SET event_json = json_replace(event_json, '$.@type', 'MusicEvent')
WHERE url LIKE 'https://allevents.in%'
  AND (
    lower(event_json->>'$.name') LIKE '% live%'
    OR lower(event_json->>'$.name') LIKE '%concert%'
    OR lower(event_json->>'$.name') LIKE '%mehfil%'
  );

UPDATE events
SET event_json = json_replace(event_json, '$.@type', 'ComedyEvent')
WHERE url LIKE 'https://allevents.in%'
  AND (
    lower(event_json->>'$.name') LIKE '%stand up%'
    OR lower(event_json->>'$.name') LIKE '%standup%'
    OR lower(event_json->>'$.name') LIKE '%comedy show%'
    OR lower(event_json->>'$.name') LIKE '%open mic%'
  );

UPDATE events
SET event_json = json_replace(event_json, '$.@type', 'LiteraryEvent')
WHERE url LIKE 'https://allevents.in%'
  AND (
    lower(event_json->>'$.name') LIKE '%poetry%'
    OR lower(event_json->>'$.name') LIKE '%storytelling%'
    OR lower(event_json->>'$.name') LIKE '%spoken word%'
    OR lower(event_json->>'$.name') LIKE '%book launch%'
  );

-- Fix specific known events from any source
UPDATE events
SET event_json = json_replace(event_json, '$.@type', 'LiteraryEvent')
WHERE
  event_json ->> '$.name' LIKE '%dialogues with books%'
  OR event_json ->> '$.name' LIKE '%Broke Bibliophiles%';

UPDATE events
SET event_json = json_replace(event_json, '$.@type', 'ScreeningEvent')
WHERE
  event_json ->> '$.name' LIKE '%movie under the stars%'
  OR event_json ->> '$.name' LIKE '%sunset cinema%';


-- ============================================================
-- SPECIAL TAGS: Source-specific
-- ============================================================

UPDATE events
SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'ARTZO'))
WHERE url LIKE '%artzo.in%';


-- ============================================================
-- NEIGHBOURHOOD TAGS
-- ============================================================

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'HAUZ-KHAS'))
WHERE event_json ->> '$.location' LIKE '%hauz khas%'
   OR event_json ->> '$.location' LIKE '%green park%'
   OR event_json ->> '$.location' LIKE '%safdarjung%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'CONNAUGHT-PLACE'))
WHERE event_json ->> '$.location' LIKE '%connaught place%'
   OR event_json ->> '$.location' LIKE '%connaught%'
   OR event_json ->> '$.location' LIKE '%janpath%'
   OR event_json ->> '$.location' LIKE '%barakhamba%'
   OR event_json ->> '$.location' LIKE '%kasturba gandhi%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LODHI'))
WHERE event_json ->> '$.location' LIKE '%lodhi%'
   OR event_json ->> '$.location' LIKE '%khan market%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'SAKET'))
WHERE event_json ->> '$.location' LIKE '%saket%'
   OR event_json ->> '$.location' LIKE '%malviya nagar%'
   OR event_json ->> '$.location' LIKE '%select city%'
   OR event_json ->> '$.location' LIKE '%lado sarai%'
   OR event_json ->> '$.location' LIKE '%sainik farm%'
   OR event_json ->> '$.location' LIKE '%neb sarai%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'SHAHPUR-JAT'))
WHERE event_json ->> '$.location' LIKE '%shahpur jat%'
   OR event_json ->> '$.location' LIKE '%siri fort%'
   OR event_json ->> '$.location' LIKE '%asiad village%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'VASANT-KUNJ'))
WHERE event_json ->> '$.location' LIKE '%vasant kunj%'
   OR event_json ->> '$.location' LIKE '%vasant vihar%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'OLD-DELHI'))
WHERE event_json ->> '$.location' LIKE '%chandni chowk%'
   OR event_json ->> '$.location' LIKE '%old delhi%'
   OR event_json ->> '$.location' LIKE '%shahjahanabad%'
   OR event_json ->> '$.location' LIKE '%jama masjid%'
   OR event_json ->> '$.location' LIKE '%lal qila%'
   OR event_json ->> '$.location' LIKE '%red fort%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'DEFCOL'))
WHERE event_json ->> '$.location' LIKE '%south ex%'
   OR event_json ->> '$.location' LIKE '%south extension%'
   OR event_json ->> '$.location' LIKE '%defence colony%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'NIZAMUDDIN'))
WHERE event_json ->> '$.location' LIKE '%nizamuddin%'
   OR event_json ->> '$.location' LIKE '%humayun%'
   OR event_json ->> '$.location' LIKE '%sunder nursery%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'LAJPAT-NAGAR'))
WHERE event_json ->> '$.location' LIKE '%lajpat nagar%'
   OR event_json ->> '$.location' LIKE '%greater kailash%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'KAROL-BAGH'))
WHERE event_json ->> '$.location' LIKE '%karol bagh%'
   OR event_json ->> '$.location' LIKE '%patel nagar%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'CIVIL-LINES'))
WHERE event_json ->> '$.location' LIKE '%civil lines%'
   OR event_json ->> '$.location' LIKE '%north campus%'
   OR event_json ->> '$.location' LIKE '%kamla nagar%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'GURUGRAM'))
WHERE event_json ->> '$.location' LIKE '%gurugram%'
   OR event_json ->> '$.location' LIKE '%gurgaon%';

UPDATE events SET event_json = json_replace(event_json, '$.keywords', json_insert(event_json -> '$.keywords', '$[#]', 'NOIDA'))
WHERE event_json ->> '$.location' LIKE '%noida%';


-- ============================================================
-- DELETED EVENTS
-- ============================================================

DELETE FROM events
WHERE url IN (
  'https://together.buzz/event/test-ghofp8gg' -- Test event
);