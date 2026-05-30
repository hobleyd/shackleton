/// Generates synthesized WAV versions of five public-domain classical pieces
/// and writes them to assets/music/.
///
/// Run from the project root:
///   dart run tool/generate_music.dart
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// ── Constants ─────────────────────────────────────────────────────────────────

const _sampleRate = 44100;
const _channels   = 1; // mono
const _bitDepth   = 16;

// ── Entry point ───────────────────────────────────────────────────────────────

void main() {
  final outDir = Directory('assets/music');
  outDir.createSync(recursive: true);

  final pieces = [
    _Piece('canon_in_d',          _canonInD,          76,  'Pachelbel – Canon in D'),
    _Piece('air_on_the_g_string', _airOnTheGString,   52,  'Bach – Air on the G String'),
    _Piece('moonlight_sonata',    _moonlightSonata,   54,  'Beethoven – Moonlight Sonata'),
    _Piece('clair_de_lune',       _clairDeLune,       66,  'Debussy – Clair de Lune'),
    _Piece('nocturne',            _chopinNocturne,    60,  'Chopin – Nocturne Op.9 No.2'),
  ];

  for (final piece in pieces) {
    final path = '${outDir.path}/${piece.filename}.wav';
    final bytes = _render(piece);
    File(path).writeAsBytesSync(bytes);
    print('✓ ${piece.description}  →  $path  '
          '(${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)');
  }
}

// ── Score data ────────────────────────────────────────────────────────────────
//
// Each entry is  (midi_note, duration_in_beats).
// Use midi = 0 for a rest.   Duration 1.0 = one quarter-note at given BPM.

// MIDI note helpers
const d4 = 62;  const e4 = 64;  const fs4 = 66; const g4 = 67;
const gs4 = 68; const a4 = 69;  const as4 = 70; const b4 = 71;
const c5 = 72;  const cs5 = 73; const d5 = 74;  const ds5 = 75;
const e5 = 76;  const fs5 = 78; const g5 = 79;  const gs5 = 80;
const a5 = 81;  const cs4 = 61; const c4 = 60;  const bf4 = 70;
const ef5 = 75; const f5 = 77;  const af4 = 68; const bf5 = 82;
const ef4 = 63; const af5 = 80; const f4 = 65;  const c3  = 48;
const cs3 = 49; const e3  = 52; const gs3 = 56; const cs6 = 85;
const d3  = 50; const a3  = 57; const b3  = 59; const fs3 = 54;
const g3  = 55; const g6  = 91; const fs6 = 90; const ef6 = 87;
const d6  = 86; const c6  = 84; const bf3 = 58; const as3 = 58;

/// Pachelbel – Canon in D (D major, two-voice texture)
/// Main soprano line, 4 bars × 8 eighth-notes, then varied repeat.
const _canonInD = [
  // Bar 1: F#5 E5 D5 C#5 B4 A4 B4 C#5
  (fs5, 0.5), (e5, 0.5), (d5, 0.5), (cs5, 0.5), (b4, 0.5), (a4, 0.5), (b4, 0.5), (cs5, 0.5),
  // Bar 2: D5 C#5 B4 A4 G4 F#4 G4 A4
  (d5, 0.5),  (cs5, 0.5),(b4, 0.5), (a4, 0.5),  (g4, 0.5), (fs4, 0.5),(g4, 0.5), (a4, 0.5),
  // Bar 3 (inner voice): B4 A4 G4 A4 B4 C#5 D5 E5
  (b4, 0.5),  (a4, 0.5), (g4, 0.5), (a4, 0.5),  (b4, 0.5), (cs5, 0.5),(d5, 0.5), (e5, 0.5),
  // Bar 4: F#5 G5 A5 G5 F#5 E5 D5 C#5
  (fs5, 0.5), (g5, 0.5), (a5, 0.5), (g5, 0.5),  (fs5, 0.5),(e5, 0.5), (d5, 0.5), (cs5, 0.5),
  // Bar 5: B4 C#5 D5 E5 F#5 G5 A5 B5
  (b4, 0.5),  (cs5, 0.5),(d5, 0.5), (e5, 0.5),  (fs5, 0.5),(g5, 0.5), (a5, 0.5), (g5, 0.5),
  // Bar 6: F#5 E5 D5 C#5 B4 A4 G4 F#4
  (fs5, 0.5), (e5, 0.5), (d5, 0.5), (cs5, 0.5), (b4, 0.5), (a4, 0.5), (g4, 0.5), (fs4, 0.5),
  // Bar 7: G4 A4 B4 C#5 D5 long
  (g4, 0.5),  (a4, 0.5), (b4, 0.5), (cs5, 0.5), (d5, 1.0), (d5, 1.0),
  // Bar 8: Rise
  (e5, 0.5),  (fs5, 0.5),(g5, 0.5), (a5, 0.5),  (b4, 0.5), (cs5, 0.5),(d5, 0.5), (e5, 0.5),
];

/// Bach – Air on the G String (D major, 52 BPM)
/// Violin I melody, opening 8 bars.
const _airOnTheGString = [
  // Bar 1: G4 long, pickup
  (g4,  2.0), (0, 0.25), (fs4, 0.25), (g4, 0.25), (a4, 0.25),
  // Bar 2: B4 C5 B4 A4 G4 F#4
  (b4,  1.0), (c5, 0.5),  (b4, 0.5),  (a4, 0.5),  (g4, 0.5),  (fs4, 0.5),
  // Bar 3: E4 F#4 G4 A4 G4
  (e4,  1.0), (fs4, 0.5), (g4, 0.5),  (a4, 0.5),  (g4, 0.5),
  // Bar 4: D4 long
  (d4,  3.0), (0, 0.5),  (e4, 0.5),
  // Bar 5: A4 B4 C5 B4 A4
  (a4,  1.5), (b4, 0.25),(c5, 0.25),  (b4, 0.5),  (a4, 0.5),
  // Bar 6: G4 A4 G4 F#4 E4
  (g4,  0.5), (a4, 0.5), (g4, 0.5),  (fs4, 0.5), (e4, 1.0),
  // Bar 7: F#4 G4 A4 D5
  (fs4, 0.5), (g4, 0.5), (a4, 0.5),  (d5, 1.5),
  // Bar 8: G4 long
  (g4,  2.0), (0, 0.5),  (fs4, 0.25),(g4, 0.25),
  // Bar 9: A4 B4 long
  (a4,  0.5), (b4, 1.5), (c5, 0.5),  (b4, 0.5),
  // Bar 10: A4 G4 F#4 G4
  (a4,  0.5), (g4, 0.5), (fs4, 0.5), (g4, 2.0),
];

/// Beethoven – Moonlight Sonata 1st mvt (C# minor, 54 BPM)
/// Triplet ostinato pattern with the famous melody above.
const _moonlightSonata = [
  // Bars 1-4: triplet ostinato C#4-E4-G#4 (four groups of three per bar)
  // Encoded as 12 eighth-note-triplets per bar.
  // Triplet duration = 1/3 beat each.
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  // Bar 2: same
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  (cs4, 0.333), (e4, 0.333), (gs4, 0.334),
  // Bar 3: B3-D#4-G#4
  (b4,  0.333), (ds5, 0.333),(gs5, 0.334),
  (b4,  0.333), (ds5, 0.333),(gs5, 0.334),
  (b4,  0.333), (ds5, 0.333),(gs5, 0.334),
  (b4,  0.333), (ds5, 0.333),(gs5, 0.334),
  // Bar 4: A3-E4-A4
  (a4,  0.333), (e5, 0.333), (a5, 0.334),
  (a4,  0.333), (e5, 0.333), (a5, 0.334),
  (a4,  0.333), (e5, 0.333), (a5, 0.334),
  (a4,  0.333), (e5, 0.333), (a5, 0.334),
  // Bar 5: Famous melody enters: G#4 dotted quarter, A4 eighth, B4 half
  (gs4, 1.5), (a4, 0.5), (b4, 2.0),
  // Bar 6: Continuation
  (b4,  1.5), (a4, 0.5), (gs4, 1.5), (fs4, 0.5),
  // Bar 7:
  (e4,  2.0), (0, 0.5), (e4, 0.5), (cs5, 1.0),
  // Bar 8: D#5 E5 falling
  (ds5, 0.5), (e5, 1.5), (ds5, 0.5),(cs5, 0.5),(b4, 1.0),
  // Bar 9: Repeat theme
  (gs4, 1.5), (a4, 0.5), (b4, 2.0),
  // Bar 10:
  (cs5, 2.0), (b4, 1.0), (a4, 1.0),
  // Bar 11:
  (gs4, 2.0), (fs4, 1.0),(gs4, 1.0),
  // Bar 12: long resolution
  (cs4, 4.0),
];

/// Debussy – Clair de Lune (Db major → Ab major, 66 BPM)
/// Opening theme.
const _clairDeLune = [
  // Bars 1-2: famous opening phrase
  (af4, 2.0), (bf4, 1.0),
  (c5,  2.0), (ef5, 1.0),
  (af5, 3.0),
  (0,   0.5), (g5, 0.5), (f5, 0.5),(ef5, 0.5),
  // Bars 3-4
  (df5 ?? d5, 2.0), (c5, 1.0),
  (bf4, 2.0), (af4, 1.0),
  (g4,  1.5), (af4, 0.5),(bf4, 2.0),
  // Bars 5-6: second phrase
  (ef5, 2.0), (f5, 1.0),
  (g5,  2.0), (af5, 1.0),
  (bf5, 3.0),
  (0,   0.5), (af5, 0.5),(g5, 0.5),(f5, 0.5),
  // Bars 7-8
  (ef5, 2.0), (d5, 1.0),
  (c5,  2.0), (bf4, 1.0),
  (af4, 3.0), (0, 1.0),
  // Bars 9-10: lyrical continuation
  (ef5, 1.5),(f5, 0.5),(g5, 2.0),
  (af5, 1.5),(g5, 0.5),(f5, 2.0),
  (ef5, 1.0),(d5, 1.0),(c5, 1.0),(bf4, 1.0),
  (af4, 4.0),
];

/// Chopin – Nocturne Op.9 No.2 (Eb major, 60 BPM in 12/8)
/// Opening vocal melody.
const _chopinNocturne = [
  // Bar 1: famous opening B♭4 – G5 – F5 – E♭5
  (bf4, 0.33),(bf4, 0.33),(g5, 1.0),
  (f5,  0.33),(ef5, 1.0), (d5, 0.33),
  (ef5, 1.5), (0, 0.5),
  // Bar 2:
  (ef5, 0.33),(f5, 0.33), (g5, 1.0),
  (bf5, 0.33),(af5, 1.0),(g5, 0.33),
  (f5,  1.5), (0, 0.5),
  // Bar 3: ornamented
  (g5,  0.5), (f5, 0.5), (ef5, 0.5),(d5, 0.5),
  (ef5, 1.0), (f5, 0.5), (g5, 0.5),
  (af5, 1.5), (0, 0.5),
  // Bar 4: resolution
  (g5,  0.5), (f5, 0.5), (ef5, 0.5),(d5, 0.5),
  (c5,  0.5), (d5, 0.5), (ef5, 1.0),
  (bf4, 2.0),
  // Bar 5: second phrase
  (bf4, 0.33),(g5, 1.0),  (f5, 0.5),
  (ef5, 1.0), (d5, 0.5),  (ef5, 1.5),
  (0,   0.5),
  // Bar 6:
  (ef5, 0.33),(f5, 0.33), (g5, 1.0),
  (af5, 0.5), (g5, 1.0),  (f5, 0.5),
  (ef5, 2.0),
  // Bar 7-8: long cadence
  (d5,  0.5), (ef5, 0.5),(f5, 0.5),(ef5, 0.5),
  (d5,  0.5), (c5, 0.5), (bf4, 1.0),
  (bf4, 0.5), (c5, 0.5), (d5, 0.5),(ef5, 0.5),
  (f5,  1.0), (g5, 1.0),
  (ef5, 4.0),
];

// Computed constant to replace null coalescing usage
const df5 = 73; // D♭5 = C#5 enharmonic

// ── Piece record ──────────────────────────────────────────────────────────────

class _Piece {
  final String filename;
  final List<(int, double)> score;
  final int bpm;
  final String description;

  const _Piece(this.filename, this.score, this.bpm, this.description);
}

// ── Renderer ──────────────────────────────────────────────────────────────────

Uint8List _render(_Piece piece) {
  final beatSec   = 60.0 / piece.bpm;
  // Calculate total duration of one pass through the score
  final passSec   = piece.score.fold(0.0, (acc, n) => acc + n.$2 * beatSec);
  // Repeat to fill ~75 seconds
  final totalSec  = max(75.0, passSec);
  final totalSamples = (_sampleRate * totalSec).ceil();

  final buffer = Float64List(totalSamples);

  double cursor = 0.0; // current sample position (fractional)
  int    pass   = 0;

  while ((cursor / _sampleRate) < totalSec) {
    for (final (midi, beats) in piece.score) {
      final durationSec = beats * beatSec;
      if (midi != 0) {
        // Fade out last 5 seconds gracefully.
        final globalTime = cursor / _sampleRate;
        final fadeEnv    = globalTime > totalSec - 5.0
            ? max(0.0, (totalSec - globalTime) / 5.0)
            : 1.0;
        _addNote(buffer, cursor.round(), _midiToHz(midi),
                 durationSec, 0.72 * fadeEnv);
      }
      cursor += durationSec * _sampleRate;
      if (cursor >= totalSamples) break;
    }
    pass++;
    if (pass > 20) break; // safety
  }

  return _encodeWav(buffer, totalSamples);
}

double _midiToHz(int midi) => 440.0 * pow(2.0, (midi - 69) / 12.0);

void _addNote(Float64List buffer, int startSample, double freq,
              double durationSec, double velocity) {
  const attack  = 0.018;
  const decay   = 0.18;
  const sustain = 0.62;
  const release = 0.45;

  final totalSamples = min(
    (durationSec * _sampleRate).round() + (release * _sampleRate).round(),
    buffer.length - startSample,
  );

  for (int i = 0; i < totalSamples; i++) {
    final t = i / _sampleRate;

    double env;
    if (t < attack) {
      env = t / attack;
    } else if (t < attack + decay) {
      env = 1.0 - (1.0 - sustain) * (t - attack) / decay;
    } else if (t < durationSec - release) {
      env = sustain;
    } else if (t < durationSec) {
      env = sustain * (1.0 - (t - (durationSec - release)) / release);
    } else {
      // Release tail after note ends
      final releaseT = t - durationSec;
      env = sustain * max(0.0, 1.0 - releaseT / release) * 0.3;
    }

    // Piano-like multi-harmonic synthesis
    final phase = 2 * pi * freq * t;
    double sample = sin(phase)              // fundamental
                  + 0.50 * sin(2 * phase)  // octave
                  + 0.28 * sin(3 * phase)  // fifth above octave
                  + 0.14 * sin(4 * phase)  // two octaves
                  + 0.07 * sin(5 * phase)  // major third above 2 octaves
                  + 0.03 * sin(6 * phase); // minor seventh above 2 octaves

    buffer[startSample + i] += sample * env * velocity * 0.18;
  }
}

Uint8List _encodeWav(Float64List buffer, int sampleCount) {
  // Soft-clip limiter
  for (int i = 0; i < sampleCount; i++) {
    final x = buffer[i];
    buffer[i] = x.abs() > 1.0 ? x.sign * (1.0 - 1.0 / (x.abs() + 1.0)) : x;
  }

  final pcmData   = Int16List(sampleCount);
  for (int i = 0; i < sampleCount; i++) {
    pcmData[i] = (buffer[i].clamp(-1.0, 1.0) * 32767).round();
  }

  final dataBytes   = pcmData.buffer.asUint8List();
  final byteRate    = _sampleRate * _channels * (_bitDepth ~/ 8);
  final blockAlign  = _channels * (_bitDepth ~/ 8);

  final header = ByteData(44);
  // RIFF chunk
  _writeString(header, 0,  'RIFF');
  header.setUint32(4,  36 + dataBytes.length, Endian.little);
  _writeString(header, 8,  'WAVE');
  // fmt sub-chunk
  _writeString(header, 12, 'fmt ');
  header.setUint32(16, 16,             Endian.little); // chunk size
  header.setUint16(20, 1,              Endian.little); // PCM
  header.setUint16(22, _channels,      Endian.little);
  header.setUint32(24, _sampleRate,    Endian.little);
  header.setUint32(28, byteRate,       Endian.little);
  header.setUint16(32, blockAlign,     Endian.little);
  header.setUint16(34, _bitDepth,      Endian.little);
  // data sub-chunk
  _writeString(header, 36, 'data');
  header.setUint32(40, dataBytes.length, Endian.little);

  final wav = Uint8List(44 + dataBytes.length);
  wav.setRange(0,  44,               header.buffer.asUint8List());
  wav.setRange(44, 44 + dataBytes.length, dataBytes);
  return wav;
}

void _writeString(ByteData data, int offset, String s) {
  for (int i = 0; i < s.length; i++) {
    data.setUint8(offset + i, s.codeUnitAt(i));
  }
}
