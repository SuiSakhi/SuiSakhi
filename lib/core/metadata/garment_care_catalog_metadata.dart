/// Shared garment-care catalog metadata. Codes remain stable in Firestore;
/// labels are presentation text and can be localized independently.
class GarmentCareCatalogMetadata {
  GarmentCareCatalogMetadata._();

  static const itemTypesByGroup = <String, Map<String, String>>{
    'washing_cleaning': {
      'saree': 'Saree',
      'blouse': 'Blouse',
      'dress': 'Dress',
      'salwar_suit': 'Salwar suit',
      'pants_jeans_skirt': 'Pants / jeans / skirt',
      'shorts': 'Shorts',
      'shirt': 'Shirt',
      'lehenga': 'Lehenga',
      'undergarment_bra': 'Underwear / bra',
      'slip_scarf': 'Slip / scarf',
      'pajamas': 'Pajamas',
      'bathrobe_gown': 'Bathrobe / gown',
      'handkerchief_stockings': 'Handkerchief / stockings',
      'vest': 'Vest',
      'dupatta': 'Dupatta',
      'other': 'Other',
    },
    'pressing_finishing': {
      'saree': 'Saree',
      'blouse': 'Blouse',
      'dress_blazer': 'Dress / blazer',
      'salwar_suit': 'Salwar suit',
      'pants_skirt': 'Pants / skirt',
      'suit_two_piece': 'Suit (2-piece)',
      'lehenga_choli': 'Lehenga choli',
      'shorts': 'Shorts',
      'scarf': 'Scarf',
      'sweater': 'Sweater',
      'coat_jacket': 'Coat / jacket',
      'overcoat': 'Overcoat',
      'petticoat_dupatta': 'Petticoat / dupatta',
      'shirt': 'Shirt',
      'other': 'Other',
    },
    'special_treatments': {
      'saree': 'Saree',
      'blouse': 'Blouse',
      'dress': 'Dress',
      'salwar_suit': 'Salwar suit',
      'lehenga': 'Lehenga',
      'fabric': 'Fabric',
      'other': 'Other',
    },
    'designer_luxury': {
      'saree': 'Saree',
      'blouse': 'Blouse',
      'dress': 'Dress',
      'lehenga': 'Lehenga',
      'bridal_wear': 'Bridal wear',
      'suit': 'Suit',
      'other': 'Other',
    },
    'home_textile': {
      'curtain': 'Curtain',
      'blanket': 'Blanket / duvet',
      'sofa_cover': 'Sofa cover',
      'rug': 'Rug / carpet',
      'other': 'Other',
    },
    'shoes_accessories': {
      'sneakers': 'Sneakers',
      'shoes': 'Shoes / boots',
      'handbag': 'Handbag',
      'backpack': 'Backpack',
      'other': 'Other',
    },
  };

  static const materialTypes = <String>[
    'Cotton',
    'Silk',
    'Georgette',
    'Chiffon',
    'Linen',
    'Velvet',
    'Organza',
    'Rayon / Viscose',
    'Crepe',
    'Satin',
    'Net / Tulle',
    'Brocade',
    'Denim',
    'Leather',
    'Rexine / Faux leather',
    'Suede',
    'Fur',
    'Polyester Blend',
    'Wool Blend',
    'Other',
  ];

  static Map<String, String> itemTypesForGroup(
    String groupCode, {
    String? serviceId,
  }) {
    final groupTypes = itemTypesByGroup[groupCode] ?? const {'other': 'Other'};
    if (serviceId != 'leather_suede_fur_care') return groupTypes;
    return {
      ...groupTypes,
      'leather': 'Leather',
      'rexine_faux_leather': 'Rexine / faux leather',
      'suede': 'Suede',
      'fur': 'Fur',
    };
  }

  static String itemLabel(
    String groupCode,
    String code, {
    String? serviceId,
  }) =>
      itemTypesForGroup(groupCode, serviceId: serviceId)[code] ??
      code.replaceAll('_', ' ');
}
