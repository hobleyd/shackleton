/// Builds XMP XML strings containing `dc:subject` keyword values.
///
/// The produced XML uses the standard RDF/XMP structure read by
/// `XmpReader` and every major photo-management tool.
class XmpWriter {
  /// Returns a complete XMP packet with [subjects] in the `dc:subject` bag.
  ///
  /// Values are XML-escaped so that arbitrary tag text is safe to embed.
  static String buildXmpWithSubjects(List<String> subjects) {
    final items = subjects
        .where((s) => s.isNotEmpty)
        .map((s) => '          <rdf:li>${_escape(s)}</rdf:li>')
        .join('\n');

    return '<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>\n'
        '<x:xmpmeta xmlns:x="adobe:ns:meta/">\n'
        '  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\n'
        '    <rdf:Description rdf:about=""\n'
        '        xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '      <dc:subject>\n'
        '        <rdf:Bag>\n'
        '$items\n'
        '        </rdf:Bag>\n'
        '      </dc:subject>\n'
        '    </rdf:Description>\n'
        '  </rdf:RDF>\n'
        '</x:xmpmeta>\n'
        '<?xpacket end="w"?>';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
