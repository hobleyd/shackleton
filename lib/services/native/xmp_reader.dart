import 'dart:convert';
import 'dart:typed_data';

/// Reads XMP metadata embedded in a JPEG APP1 segment.
///
/// Uses simple regex matching against the XMP XML text. This avoids pulling
/// in a full XML parser while covering the standard rdf:Bag structure used by
/// all major photo-management tools.
class XmpReader {
  /// Reads dc:subject values from raw XMP bytes (after the namespace prefix).
  static List<String> readSubjects(Uint8List data) {
    final xml = utf8.decode(data, allowMalformed: true);
    return _extractBagItems(xml, 'dc:subject');
  }

  static List<String> _extractBagItems(String xml, String elementName) {
    final bagPattern = RegExp(
      '<$elementName[^>]*>\\s*<rdf:Bag[^>]*>(.*?)</rdf:Bag>\\s*</$elementName>',
      dotAll: true,
    );
    final bagMatch = bagPattern.firstMatch(xml);
    if (bagMatch == null) return const [];

    final bagContent = bagMatch.group(1)!;
    final liPattern = RegExp('<rdf:li[^>]*>(.*?)</rdf:li>', dotAll: true);
    final results = <String>[];
    for (final match in liPattern.allMatches(bagContent)) {
      final value = match.group(1)!.trim();
      if (value.isNotEmpty) results.add(value);
    }
    return results;
  }
}
