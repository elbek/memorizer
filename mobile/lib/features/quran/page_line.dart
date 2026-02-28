/// Represents a single rendered line on a Quran page.
sealed class PageLine {
  const PageLine();
}

/// A line of QCF glyph text.
class TextLine extends PageLine {
  const TextLine(this.text);
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextLine && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// An ornamental surah header banner.
class HeaderLine extends PageLine {
  const HeaderLine(this.surahNumber);
  final int surahNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeaderLine && other.surahNumber == surahNumber;

  @override
  int get hashCode => surahNumber.hashCode;
}

/// The Bismillah line before a surah's text.
class BismillahLine extends PageLine {
  const BismillahLine();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BismillahLine;

  @override
  int get hashCode => 0;
}
