/// Reusable, editable starting points for a Partner's completion record.
///
/// These are prompts, not instructions to use a particular process. Partners
/// must follow the garment label, inspection findings and customer approval.
class GarmentCareCompletionTemplate {
  const GarmentCareCompletionTemplate({
    required this.id,
    required this.name,
    required this.methodUsed,
    this.serviceIds = const [],
    this.materialKeywords = const [],
    this.processDetails = '',
    this.finishingDetails = '',
    this.qualityNotes = '',
    this.isBuiltIn = false,
    this.versionId = '',
  });

  final String id;
  final String name;
  final List<String> serviceIds;
  final List<String> materialKeywords;
  final String methodUsed;
  final String processDetails;
  final String finishingDetails;
  final String qualityNotes;
  final bool isBuiltIn;
  final String versionId;

  factory GarmentCareCompletionTemplate.fromMap(
    Map<String, dynamic> map, {
    String versionId = '',
  }) => GarmentCareCompletionTemplate(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    serviceIds: _stringList(map['serviceIds']),
    materialKeywords: _stringList(map['materialKeywords']),
    methodUsed: map['methodUsed']?.toString() ?? '',
    processDetails: map['processDetails']?.toString() ?? '',
    finishingDetails: map['finishingDetails']?.toString() ?? '',
    qualityNotes: map['qualityNotes']?.toString() ?? '',
    isBuiltIn: map['isBuiltIn'] == true,
    versionId: map['versionId']?.toString() ?? versionId,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'serviceIds': serviceIds,
    'materialKeywords': materialKeywords,
    'methodUsed': methodUsed,
    'processDetails': processDetails,
    'finishingDetails': finishingDetails,
    'qualityNotes': qualityNotes,
    if (versionId.isNotEmpty) 'versionId': versionId,
  };

  bool appliesTo({required String serviceId, required String material}) {
    final serviceMatches = serviceIds.isEmpty || serviceIds.contains(serviceId);
    if (!serviceMatches || materialKeywords.isEmpty) return serviceMatches;
    final normalizedMaterial = material.toLowerCase().trim();
    return normalizedMaterial.isEmpty ||
        materialKeywords.any(
          (keyword) => normalizedMaterial.contains(keyword.toLowerCase()),
        );
  }

  static List<String> _stringList(Object? value) =>
      (value as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
}

const List<GarmentCareCompletionTemplate>
garmentCareStarterCompletionTemplates = [
  GarmentCareCompletionTemplate(
    id: 'starter_wash_iron',
    name: 'Wash and iron · care label followed',
    serviceIds: ['wash_iron'],
    methodUsed: 'Wash and iron as permitted by the care label',
    processDetails:
        'Checked the care label and inspection notes. Used a suitable wash cycle and detergent for this garment.',
    finishingDetails:
        'Dried and pressed using settings permitted by the care label.',
    qualityNotes:
        'Checked cleanliness, seams, buttons and overall finish.',
    isBuiltIn: true,
    versionId: 'starter_v1',
  ),
  GarmentCareCompletionTemplate(
    id: 'starter_wash_fold',
    name: 'Wash and fold · care label followed',
    serviceIds: ['wash_fold'],
    methodUsed: 'Wash and fold as permitted by the care label',
    processDetails:
        'Checked the care label and inspection notes. Used a suitable wash cycle and detergent for this garment.',
    finishingDetails:
        'Dried and folded or reshaped as suitable for the garment and care label.',
    qualityNotes:
        'Checked cleanliness, seams, buttons and that all accepted items are accounted for.',
    isBuiltIn: true,
    versionId: 'starter_v1',
  ),
  GarmentCareCompletionTemplate(
    id: 'starter_pressing',
    name: 'Ironing and pressing · label checked',
    serviceIds: ['steam_ironing', 'roll_pressing', 'form_pressing'],
    methodUsed: 'Ironing or pressing as permitted by the care label',
    processDetails:
        'Checked the care label and fabric before pressing. Used a suitable heat and steam setting for this garment.',
    finishingDetails:
        'Finished seams and edges using a suitable pressing method.',
    qualityNotes:
        'Checked shape, surface and finish for shine marks or pressing damage.',
    isBuiltIn: true,
    versionId: 'starter_v1',
  ),
  GarmentCareCompletionTemplate(
    id: 'starter_dry_cleaning',
    name: 'Dry cleaning · approved process',
    serviceIds: ['dry_cleaning', 'premium_wet_cleaning'],
    methodUsed: 'Professional cleaning process approved for this garment',
    processDetails:
        'Checked the care label, inspection notes and approved service before cleaning.',
    finishingDetails:
        'Finished and presented the garment using a suitable professional method.',
    qualityNotes:
        'Checked appearance, seams, trims and overall finish.',
    isBuiltIn: true,
    versionId: 'starter_v1',
  ),
  GarmentCareCompletionTemplate(
    id: 'starter_delicate',
    name: 'Delicate garment · gentle process',
    materialKeywords: ['silk', 'wool', 'cashmere', 'delicate', 'embellish'],
    methodUsed: 'Gentle care process approved for this garment',
    processDetails:
        'Checked the care label, fabric and inspection findings. Used a gentle process suitable for the approved service.',
    finishingDetails:
        'Reshaped and dried or finished as suitable for the fabric and care label.',
    qualityNotes:
        'Checked fabric integrity, trims, seams and finish.',
    isBuiltIn: true,
    versionId: 'starter_v1',
  ),
  GarmentCareCompletionTemplate(
    id: 'starter_cotton_linen',
    name: 'Cotton or linen · care label followed',
    serviceIds: ['wash_fold', 'wash_iron'],
    materialKeywords: ['cotton', 'linen'],
    methodUsed: 'Care-label-compliant cleaning for this cotton or linen item',
    processDetails:
        'Checked the care label and inspection notes. Selected the wash process and settings permitted for this garment.',
    finishingDetails:
        'Dried and pressed using a method and settings permitted by the care label.',
    qualityNotes:
        'Checked cleanliness, seams, shape and overall finish.',
    isBuiltIn: true,
    versionId: 'starter_v1',
  ),
  GarmentCareCompletionTemplate(
    id: 'starter_synthetic_blend',
    name: 'Synthetic or blended fabric · label checked',
    serviceIds: ['wash_fold', 'wash_iron', 'steam_ironing'],
    materialKeywords: ['polyester', 'nylon', 'synthetic', 'blend'],
    methodUsed: 'Care-label-compliant care for this synthetic or blended item',
    processDetails:
        'Checked the care label and fabric. Selected a suitable process and settings permitted for this garment.',
    finishingDetails:
        'Finished using suitable settings permitted by the care label.',
    qualityNotes:
        'Checked shape, seams and surface for damage or unwanted shine.',
    isBuiltIn: true,
    versionId: 'starter_v1',
  ),
];
