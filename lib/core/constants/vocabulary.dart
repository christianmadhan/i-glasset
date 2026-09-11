/// The Danish option lists the design offers as chips. Hosts and guests can
/// always add their own, so these are starting points rather than a closed set.
class Vocabulary {
  const Vocabulary._();

  static const aromas = [
    'Kirsebær', 'Solbær', 'Blåbær', 'Blomme', 'Rose', 'Violer',
    'Urter', 'Tjære', 'Tobak', 'Læder', 'Vanilje', 'Peber',
  ];

  static const flavours = [
    'Rød frugt', 'Mørk frugt', 'Høj syre', 'Stramme tanniner',
    'Blød tannin', 'Lakrids', 'Urter', 'Peber', 'Fad',
  ];

  static const grapes = [
    'Nebbiolo', 'Sangiovese', 'Barbera', 'Aglianico',
    'Lagrein', 'Cannonau', 'Cabernet', 'Corvina',
  ];

  static const countries = ['Italien', 'Frankrig', 'Spanien', 'Portugal', 'Østrig'];

  static const regions = [
    'Piemonte', 'Toscana', 'Alto Adige', 'Campania', 'Sardinien', 'Veneto',
  ];

  static const extras = [
    'Økologisk', 'Ståltank', 'Tre år på store fade',
    'Vulkansk jord', 'Gamle stokke', 'Højtliggende marker',
  ];

  /// Tasting categories a host can pick.
  static const categories = ['Vin', 'Øl', 'Whisky', 'Rom', 'Spiritus', 'Kaffe', 'Andet'];

  /// What a group says it drinks.
  static const groupFocus = ['Vin', 'Øl', 'Whisky', 'Spiritus', 'Kaffe', 'Blandet'];

  /// Filters on "Mine topsmagninger".
  static const productFilters = [
    'Alle', 'Rødvin', 'Hvidvin', 'Orangevin', 'Mousserende', 'Øl', 'Whisky', 'Andet',
  ];

  /// Guess-sheet slider ranges.
  static const priceMin = 50.0;
  static const priceMax = 1500.0;
  static const priceStep = 25.0;

  static const abvMin = 8.0;
  static const abvMax = 20.0;
  static const abvStep = 0.5;

  static const vintageMin = 1990.0;
  static const vintageMax = 2026.0;

  /// At most four aroma and four flavour notes may be picked.
  static const maxNotes = 4;
}

/// The four onboarding cards.
class OnboardingStep {
  const OnboardingStep({
    required this.mark,
    required this.title,
    required this.body,
  });

  final String mark;
  final String title;
  final String body;

  static const steps = [
    OnboardingStep(
      mark: '1',
      title: 'Værten samler flaskerne',
      body: 'En i gruppen opretter aftenens smagning, vælger antal glas og '
          'skriver produkterne ind. Deltagerne ser ingenting endnu.',
    ),
    OnboardingStep(
      mark: '2',
      title: 'I deltager med en kode',
      body: 'Koden står i gruppen. Alle åbner appen, skriver koden og lander '
          'i den samme lobby.',
    ),
    OnboardingStep(
      mark: '3',
      title: 'Smag, gæt og bedøm',
      body: 'Hvert glas er skjult. Giv en karakter, skriv dine noter, og gæt '
          'drue, pris, årgang og resten hvis I spiller om point.',
    ),
    OnboardingStep(
      mark: '4',
      title: 'Afsløring og arkiv',
      body: 'Værten afslører produktet, I ser gruppens karakterer og jeres '
          'point. Alt gemmes i gruppens historik og i dit eget arkiv.',
    ),
  ];
}

/// One "Format og regler" setting: a label, a hint, and its options.
class ConfigChoice {
  const ConfigChoice({
    required this.key,
    required this.label,
    required this.hint,
    required this.options,
  });

  final String key;
  final String label;
  final String hint;
  final List<String> options;

  static const all = [
    ConfigChoice(
      key: 'blind',
      label: 'Hvad er skjult',
      hint: 'Blind-niveau',
      options: ['Alt skjult', 'Kun navnet skjult', 'Åben smagning'],
    ),
    ConfigChoice(
      key: 'reveal',
      label: 'Afsløring',
      hint: 'Hvornår',
      options: ['Efter hvert glas', 'Til sidst', 'Værten bestemmer'],
    ),
    ConfigChoice(
      key: 'order',
      label: 'Rækkefølge',
      hint: 'Glassenes orden',
      options: ['Fast', 'Tilfældig pr. deltager'],
    ),
    ConfigChoice(
      key: 'scale',
      label: 'Karakterskala',
      hint: 'Deltagernes bedømmelse',
      options: ['1–10', '1–100'],
    ),
    ConfigChoice(
      key: 'show_others',
      label: 'Se andres karakterer',
      hint: 'Synlighed',
      options: ['Efter afsløring', 'Straks', 'Aldrig'],
    ),
    ConfigChoice(
      key: 'timer',
      label: 'Tid pr. glas',
      hint: 'Nedtælling',
      options: ['Ingen', '5 min', '10 min'],
    ),
    ConfigChoice(
      key: 'code_mode',
      label: 'Tilmeldingskode',
      hint: 'Deltagerkode',
      options: ['Automatisk', 'Vælg selv'],
    ),
    ConfigChoice(
      key: 'guests',
      label: 'Hvem kan deltage',
      hint: 'Adgang',
      options: ['Kun gruppen', 'Gruppen og gæster'],
    ),
  ];
}
