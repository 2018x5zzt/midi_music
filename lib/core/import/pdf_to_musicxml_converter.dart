import 'dart:io';

abstract class PdfToMusicXmlConverter {
  Future<String> convert(File pdfFile);
}
