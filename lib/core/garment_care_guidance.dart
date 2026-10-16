/// Conservative report guidance based on the selected material description.
/// It never claims a fibre composition or replaces a verified care label.
class GarmentCareGuidance {
  GarmentCareGuidance._();

  static const String _baseline =
      "Fibre composition and care label have not been verified. Follow the garment's verified care label when available. Until confirmed, avoid bleach and high heat; test colourfastness on a hidden area. For delicate, structured, embellished, or colour-sensitive garments, consult a textile-care professional before cleaning.";

  static String forMaterial(String materialName, String materialDescription) {
    final selected = '$materialName $materialDescription'.toLowerCase();
    if (RegExp(
      r'silk|velvet|georgette|chiffon|organza|net|zari|embroider|bridal|sequin|bead',
    ).hasMatch(selected)) {
      return '$_baseline This selected material or finish needs gentle handling; do not assume machine-washability.';
    }
    if (RegExp(r'cotton|linen').hasMatch(selected)) {
      return '$_baseline Shrinkage, dye-fastness, and ironing needs depend on the fabric finish.';
    }
    return _baseline;
  }
}
