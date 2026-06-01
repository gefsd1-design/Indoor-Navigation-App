import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/office_node.dart';
import '../models/office_graph_factory.dart';

/// Service to recognize lab/location from captured images
/// Uses image matching (mock implementation)
class ImageRecognitionService {
  static const int _inputSize = 224;
  static const double _matchThreshold = 0.55;
  static const double _hashMatchThreshold = 0.78;
  static const int _minOrbMatches = 4;
  static const double _orbGoodMatchDistance = 70.0;
  static const double _orbScoreThreshold = 0.2;
  static const double _orbLowConfidenceThreshold = 0.2;
  static const double _orbRatioThreshold = 0.75;
  static const double _blurVarianceThreshold = 25.0;
  static const double _ocrMatchThreshold = 0.55;

  static Interpreter? _interpreter;
  static bool _embeddingReady = false;
  static cv.ORB? _orb;
  static cv.BFMatcher? _bfMatcher;
  static bool _initialized = false;
  static final List<_AssetEmbedding> _assetEmbeddings = [];
  static final List<_AssetHash> _assetHashes = [];
  static final List<_AssetDescriptor> _assetDescriptors = [];
  static final List<_NormalizedRoomLabel> _roomLabels = [];

  /// Lab metadata used after matching.
  static final Map<String, LabImageProfile> labDatabase = {
    'TIH_Board': LabImageProfile(
      labId: 'TIH_Board',
      labName: 'TIH Board',
      keywords: ['tih', 'starting', 'board', 'arch', 'door'],
      confidence: 0.9,
      latitude: 13.721165,
      longitude: 79.590786,
    ),
    'Cafeteria': LabImageProfile(
      labId: 'Cafeteria',
      labName: 'Cafeteria',
      keywords: ['cafeteria', 'coffee', 'food', 'dining'],
      confidence: 0.9,
      latitude: 13.720465,
      longitude: 79.589786,
    ),
    'CEO_Room': LabImageProfile(
      labId: 'CEO_Room',
      labName: 'CEO Room',
      keywords: ['ceo', 'executive', 'office'],
      confidence: 0.9,
      latitude: 13.720465,
      longitude: 79.591786,
    ),
    'Meeting_Room': LabImageProfile(
      labId: 'Meeting_Room',
      labName: 'Meeting Room',
      keywords: ['meeting', 'conference', 'main meeting'],
      confidence: 0.9,
      latitude: 13.719665,
      longitude: 79.590786,
    ),
    'GNSS_Lab': LabImageProfile(
      labId: 'GNSS_Lab',
      labName: 'GNSS Lab',
      keywords: ['gnss', 'gps'],
      confidence: 0.9,
      latitude: 13.718865,
      longitude: 79.590786,
    ),
    'LiDAR_Lab': LabImageProfile(
      labId: 'LiDAR_Lab',
      labName: 'LiDAR Lab',
      keywords: ['lidar'],
      confidence: 0.9,
      latitude: 13.717465,
      longitude: 79.590786,
    ),
    'Washrooms': LabImageProfile(
      labId: 'Washrooms',
      labName: 'Washrooms',
      keywords: ['washroom', 'washrooms', 'gents', 'ladies'],
      confidence: 0.9,
      latitude: 13.716465,
      longitude: 79.589786,
    ),
    'Computational_Lab': LabImageProfile(
      labId: 'Computational_Lab',
      labName: 'Computational Lab',
      keywords: ['computational', 'computer'],
      confidence: 0.9,
      latitude: 13.716465,
      longitude: 79.591786,
    ),
    'Gym_Room': LabImageProfile(
      labId: 'Gym_Room',
      labName: 'Gym Room',
      keywords: ['gym'],
      confidence: 0.9,
      latitude: 13.717965,
      longitude: 79.585786,
    ),
    'GIS_Lab': LabImageProfile(
      labId: 'GIS_Lab',
      labName: 'GIS Lab',
      keywords: ['gis'],
      confidence: 0.9,
      latitude: 13.717965,
      longitude: 79.586786,
    ),
    'CV_Lab': LabImageProfile(
      labId: 'CV_Lab',
      labName: 'CV Lab',
      keywords: ['cv lab', 'cv'],
      confidence: 0.9,
      latitude: 13.717965,
      longitude: 79.587586,
    ),
    'PD_Room': LabImageProfile(
      labId: 'PD_Room',
      labName: 'PD Room',
      keywords: ['pd room', 'pd'],
      confidence: 0.9,
      latitude: 13.717965,
      longitude: 79.588386,
    ),
    'Admin_Room': LabImageProfile(
      labId: 'Admin_Room',
      labName: 'Administrative Room',
      keywords: ['admin', 'administrative', 'front desk'],
      confidence: 0.9,
      latitude: 13.717965,
      longitude: 79.589186,
    ),
    'GEO_Intel_Lab': LabImageProfile(
      labId: 'GEO_Intel_Lab',
      labName: 'GEO Intel Lab',
      keywords: ['geo', 'intel', 'geo intel'],
      confidence: 0.9,
      latitude: 13.717965,
      longitude: 79.589986,
    ),
    'Discussion_Area': LabImageProfile(
      labId: 'Discussion_Area',
      labName: 'Discussion Area',
      keywords: ['discussion'],
      confidence: 0.9,
      latitude: 13.717965,
      longitude: 79.590586,
    ),
  };

  /// Recognize lab/location by matching visual embeddings against TIH images.
  static Future<LabDetectionResult?> recognizeLabFromImage(
      File imageFile) async {
    try {
      final outcome = await matchLocationFromImage(imageFile);
      if (outcome.detection != null) {
        return outcome.detection;
      }

      if (outcome.hint != null) {
        return null;
      }

      final capturedBytes = await imageFile.readAsBytes();
      final embeddingResult = _matchByEmbedding(imageFile, capturedBytes);
      if (embeddingResult != null) {
        return embeddingResult;
      }

      final hashResult = _matchByHash(imageFile, capturedBytes);
      if (hashResult != null) {
        return hashResult;
      }

      return _fallbackByFileName(imageFile);
    } catch (e) {
      return null;
    }
  }

  /// Match captured image against the on-device reference set.
  static Future<ImageMatchOutcome> matchLocationFromImage(
      File imageFile) async {
    try {
      await _ensureInitialized();

      final bytes = await imageFile.readAsBytes();
      final gray = _decodeToGray(bytes);
      if (gray == null) {
        return const ImageMatchOutcome(
          hint: 'Could not decode image. Please re-capture.',
        );
      }

      final blurScore = _laplacianVariance(gray);
      final blurHint = blurScore < _blurVarianceThreshold
          ? 'Blur Detected - Please Re-capture'
          : null;

      final match = _matchByOrb(gray);
      gray.dispose();

      if (match == null) {
        final ocrResult = await _matchByOcr(imageFile);
        if (ocrResult != null) {
          return ImageMatchOutcome(
            detection: ocrResult,
            confidenceScore: ocrResult.confidence,
            locationName: ocrResult.labName,
            hint: blurHint,
          );
        }
        final fallback =
            _matchByEmbedding(imageFile, bytes, allowLowConfidence: true) ??
                _matchByHash(imageFile, bytes, allowLowConfidence: true);
        if (fallback != null) {
          return ImageMatchOutcome(
            detection: fallback,
            confidenceScore: fallback.confidence,
            locationName: fallback.labName,
            hint: blurHint,
          );
        }
        return ImageMatchOutcome(
          hint: blurHint ?? 'Low Confidence - Please Re-capture',
        );
      }

      final profile = labDatabase[match.labId];
      if (profile == null) {
        return ImageMatchOutcome(
          hint: blurHint ?? 'Low Confidence - Please Re-capture',
        );
      }

      if (match.score < _orbLowConfidenceThreshold) {
        final ocrResult = await _matchByOcr(imageFile);
        if (ocrResult != null) {
          return ImageMatchOutcome(
            detection: ocrResult,
            confidenceScore: ocrResult.confidence,
            locationName: ocrResult.labName,
            hint: blurHint,
          );
        }
        final fallback =
            _matchByEmbedding(imageFile, bytes, allowLowConfidence: true) ??
                _matchByHash(imageFile, bytes, allowLowConfidence: true);
        if (fallback != null) {
          return ImageMatchOutcome(
            detection: fallback,
            confidenceScore: fallback.confidence,
            locationName: fallback.labName,
            hint: blurHint,
          );
        }
        // Return best match even if low confidence to avoid hard failure.
        final confidence = (0.5 + (match.score * 0.3)).clamp(0.5, 0.8);
        final detection = LabDetectionResult(
          labId: profile.labId,
          labName: profile.labName,
          confidence: confidence,
          latitude: profile.latitude,
          longitude: profile.longitude,
          imageFile: imageFile,
          imageName: match.imageName,
          timestamp: DateTime.now(),
        );
        return ImageMatchOutcome(
          detection: detection,
          confidenceScore: match.score,
          locationName: profile.labName,
          hint: blurHint,
        );
      }

      final confidence = (0.6 + (match.score * 0.4)).clamp(0.6, 0.96);
      final detection = LabDetectionResult(
        labId: profile.labId,
        labName: profile.labName,
        confidence: confidence,
        latitude: profile.latitude,
        longitude: profile.longitude,
        imageFile: imageFile,
        imageName: match.imageName,
        timestamp: DateTime.now(),
      );

      return ImageMatchOutcome(
        detection: detection,
        confidenceScore: match.score,
        locationName: profile.labName,
        hint: blurHint,
      );
    } catch (e) {
      return const ImageMatchOutcome(
        hint: 'Low Confidence - Please Re-capture',
      );
    }
  }

  /// Match multiple captured images and fuse the results.
  static Future<ImageMatchOutcome> matchLocationFromImages(
      List<File> imageFiles) async {
    if (imageFiles.isEmpty) {
      return const ImageMatchOutcome(
        hint: 'No images captured. Please re-capture.',
      );
    }

    final outcomes = await Future.wait(imageFiles.map(matchLocationFromImage));

    final candidates = <String, _FusionCandidate>{};
    for (final outcome in outcomes) {
      final detection = outcome.detection;
      if (detection == null) continue;

      final score = outcome.confidenceScore ?? detection.confidence;
      final entry = candidates.putIfAbsent(
        detection.labId,
        () => _FusionCandidate(detection: detection),
      );
      entry.scoreSum += score;
      entry.count += 1;
      if (score > entry.bestScore) {
        entry.bestScore = score;
        entry.bestDetection = detection;
      }
    }

    if (candidates.isEmpty) {
      return ImageMatchOutcome(
        hint: _mergeOutcomeHints(outcomes) ??
            'Low Confidence - Please Re-capture',
      );
    }

    _FusionCandidate? best;
    double bestScore = -1;
    for (final entry in candidates.values) {
      final averageScore = entry.scoreSum / entry.count;
      final fusedScore = averageScore + (entry.count - 1) * 0.05;
      if (best == null || fusedScore > bestScore) {
        best = entry;
        bestScore = fusedScore;
      } else if (fusedScore == bestScore && entry.bestScore > best.bestScore) {
        best = entry;
        bestScore = fusedScore;
      }
    }

    final chosen = best!.bestDetection;
    final combinedConfidence = (best.scoreSum / best.count).clamp(0.0, 1.0);

    return ImageMatchOutcome(
      detection: chosen,
      confidenceScore: combinedConfidence,
      locationName: chosen.labName,
      hint: _mergeOutcomeHints(outcomes),
    );
  }

  static String? _mergeOutcomeHints(List<ImageMatchOutcome> outcomes) {
    bool hasBlur = false;
    for (final outcome in outcomes) {
      final hint = outcome.hint;
      if (hint == null) continue;
      if (hint.toLowerCase().contains('blur')) {
        hasBlur = true;
      } else {
        return hint;
      }
    }
    return hasBlur ? 'Blur Detected - Please Re-capture' : null;
  }

  /// Get offline node reference from detected lab ID
  static OfficeNode? getOfficeNodeFromLabId(String labId) {
    final graph = OfficeGraphFactory.buildGraph();
    return graph.nodes[labId];
  }

  /// Verify detection confidence
  static bool isHighConfidence(double confidence) {
    return confidence >= 0.80; // 80% threshold
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    debugPrint('[NNES] Initializing TFLite model...');
    if (_interpreter == null) {
      try {
        _interpreter =
            await Interpreter.fromAsset('assets/models/embedding_model.tflite');
        _embeddingReady = true;
      } catch (_) {
        try {
          _interpreter =
              await Interpreter.fromAsset('models/embedding_model.tflite');
          _embeddingReady = true;
        } catch (e) {
          debugPrint('[NNES] Embedding model not available: $e');
          _embeddingReady = false;
        }
      }
    }
    _orb ??= cv.ORB.create(
      nFeatures: 900,
      scaleFactor: 1.2,
      nLevels: 8,
      edgeThreshold: 31,
      patchSize: 31,
      fastThreshold: 10,
    );
    _bfMatcher ??= cv.BFMatcher.create(type: cv.NORM_HAMMING, crossCheck: true);
    _buildRoomLabelIndex();
    debugPrint('[NNES] Model loaded. Building TIH embeddings...');
    await _buildAssetDescriptors();
    await _buildAssetEmbeddings();
    _initialized = true;
    debugPrint('[NNES] Image matcher ready.');
  }

  static Future<void> _buildAssetDescriptors() async {
    if (_assetDescriptors.isNotEmpty) return;

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final manifest = Map<String, dynamic>.from(
        (manifestContent.isEmpty) ? {} : jsonDecode(manifestContent));

    final assetPaths = manifest.keys
        .where((path) => path.startsWith('assets/office_dataset/TIH Photos/'))
        .toList();

    debugPrint('[NNES] Found ${assetPaths.length} reference assets.');

    int processed = 0;
    for (final assetPath in assetPaths) {
      final imageName = _fileName(assetPath);
      final labId = _mapFileNameToLabId(imageName);
      if (labId == null) continue;

      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final gray = _decodeToGray(bytes);
      if (gray == null) continue;

      final descriptor = _extractOrbDescriptors(gray);
      gray.dispose();

      if (descriptor == null) continue;
      _assetDescriptors.add(_AssetDescriptor(
        labId: labId,
        imageName: imageName,
        descriptors: descriptor.descriptors,
        keypointCount: descriptor.keypointCount,
      ));

      processed += 1;
      if (processed % 6 == 0) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    debugPrint('[NNES] Built ${_assetDescriptors.length} ORB descriptors.');
  }

  static cv.Mat? _decodeToGray(Uint8List bytes) {
    final preprocessed = _preprocessBytes(bytes);
    final mat = cv.imdecode(preprocessed, cv.IMREAD_GRAYSCALE);
    if (mat.isEmpty) {
      mat.dispose();
      return null;
    }
    final equalized = cv.equalizeHist(mat);
    mat.dispose();
    if (equalized.isEmpty) {
      equalized.dispose();
      return null;
    }
    return equalized;
  }

  static double _laplacianVariance(cv.Mat gray) {
    final lap = cv.laplacian(gray, cv.MatType.CV_64F);
    final (_, stddev) = cv.meanStdDev(lap);
    final variance = stddev.val1 * stddev.val1;
    lap.dispose();
    return variance;
  }

  static _DescriptorResult? _extractOrbDescriptors(cv.Mat gray) {
    final orb = _orb;
    if (orb == null) return null;

    final (keypoints, descriptors) = orb.detectAndCompute(
      gray,
      cv.Mat.empty(),
    );

    if (descriptors.isEmpty || keypoints.isEmpty) {
      descriptors.dispose();
      keypoints.dispose();
      return null;
    }

    final keypointCount = keypoints.length;
    keypoints.dispose();
    return _DescriptorResult(
      descriptors: descriptors,
      keypointCount: keypointCount,
    );
  }

  static _OrbMatchResult? _matchByOrb(cv.Mat gray) {
    if (_assetDescriptors.isEmpty) return null;

    final query = _extractOrbDescriptors(gray);
    if (query == null) return null;

    final matcher = _bfMatcher;
    if (matcher == null) {
      query.descriptors.dispose();
      return null;
    }

    _OrbMatchResult? best;
    for (final asset in _assetDescriptors) {
      if (asset.descriptors.isEmpty) continue;
      final matches = matcher.match(query.descriptors, asset.descriptors);
      if (matches.isEmpty) {
        matches.dispose();
        continue;
      }

      final ratioScore = _ratioScore(matches);
      if (ratioScore > _orbRatioThreshold) {
        matches.dispose();
        continue;
      }

      double distanceSum = 0.0;
      int good = 0;
      for (final match in matches) {
        distanceSum += match.distance;
        if (match.distance <= _orbGoodMatchDistance) {
          good += 1;
        }
      }

      final total = matches.length;
      matches.dispose();

      if (total < _minOrbMatches) {
        continue;
      }

      final meanDistance = distanceSum / total;
      final distanceScore = (1.0 - (meanDistance / 256.0)).clamp(0.0, 1.0);
      final matchScore = (good / total).clamp(0.0, 1.0);
      final score = (matchScore * 0.7) + (distanceScore * 0.3);

      if (best == null || score > best.score) {
        best = _OrbMatchResult(
          labId: asset.labId,
          imageName: asset.imageName,
          score: score,
          matchCount: total,
        );
      }
    }

    query.descriptors.dispose();

    if (best == null || best.score < _orbScoreThreshold) {
      return null;
    }

    return best;
  }

  static Future<void> _buildAssetEmbeddings() async {
    if (_assetEmbeddings.isNotEmpty || _assetHashes.isNotEmpty) return;

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final manifest = Map<String, dynamic>.from(
        (manifestContent.isEmpty) ? {} : jsonDecode(manifestContent));

    final assetPaths = manifest.keys
        .where((path) => path.startsWith('assets/office_dataset/TIH Photos/'))
        .toList();

    debugPrint('[NNES] Found ${assetPaths.length} TIH assets.');
    if (!_embeddingReady) {
      debugPrint('[NNES] Embedding model unavailable. Hash matching only.');
    }

    final perLabCount = <String, int>{};
    int processed = 0;

    for (final assetPath in assetPaths) {
      final imageName = _fileName(assetPath);
      final labId = _mapFileNameToLabId(imageName);
      if (labId == null) continue;
      if ((perLabCount[labId] ?? 0) >= 6) continue;
      if (_assetHashes.length >= 80) break;

      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final hash = _computeAverageHash(bytes);
      if (hash != null) {
        _assetHashes.add(_AssetHash(
          labId: labId,
          imageName: imageName,
          hash: hash,
        ));
      }

      if (_embeddingReady) {
        final embedding = _extractEmbedding(bytes);
        if (embedding.isNotEmpty) {
          _assetEmbeddings.add(
            _AssetEmbedding(
              labId: labId,
              imageName: imageName,
              embedding: embedding,
            ),
          );
        }
      }

      perLabCount[labId] = (perLabCount[labId] ?? 0) + 1;
      processed += 1;
      if (processed % 4 == 0) {
        debugPrint('[NNES] Embedded $processed images...');
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    debugPrint(
        '[NNES] Built ${_assetEmbeddings.length} embeddings and ${_assetHashes.length} hashes.');
  }

  static LabDetectionResult? _matchByEmbedding(
      File imageFile, Uint8List capturedBytes,
      {bool allowLowConfidence = false}) {
    if (_assetEmbeddings.isEmpty) {
      debugPrint('[NNES] No TIH embeddings available.');
      return null;
    }

    final queryEmbedding = _extractEmbedding(capturedBytes);
    if (queryEmbedding.isEmpty) {
      debugPrint('[NNES] Failed to extract embedding from capture.');
      return null;
    }

    _MatchResult? best;
    for (final item in _assetEmbeddings) {
      final similarity = _cosineSimilarity(queryEmbedding, item.embedding);
      if (best == null || similarity > best.similarity) {
        best = _MatchResult(item, similarity);
      }
    }

    if (best == null) return null;
    if (best.similarity < _matchThreshold && !allowLowConfidence) {
      debugPrint(
          '[NNES] Low embedding similarity: ${best.similarity.toStringAsFixed(3)}');
      return null;
    }

    final profile = labDatabase[best.item.labId];
    if (profile == null) {
      return null;
    }

    final confidence = best.similarity < _matchThreshold
        ? (0.55 + (best.similarity * 0.2)).clamp(0.55, 0.75)
        : (0.7 +
                ((best.similarity - _matchThreshold) * 0.3) /
                    (1 - _matchThreshold))
            .clamp(0.7, 0.95);

    return LabDetectionResult(
      labId: profile.labId,
      labName: profile.labName,
      confidence: confidence,
      latitude: profile.latitude,
      longitude: profile.longitude,
      imageFile: imageFile,
      imageName: best.item.imageName,
      timestamp: DateTime.now(),
    );
  }

  static LabDetectionResult? _matchByHash(
      File imageFile, Uint8List capturedBytes,
      {bool allowLowConfidence = false}) {
    if (_assetHashes.isEmpty) {
      debugPrint('[NNES] No TIH hashes available.');
      return null;
    }

    final queryHash = _computeAverageHash(capturedBytes);
    if (queryHash == null) {
      debugPrint('[NNES] Failed to compute hash from capture.');
      return null;
    }

    _HashMatchResult? best;
    for (final item in _assetHashes) {
      final distance = _hammingDistance(queryHash, item.hash);
      if (best == null || distance < best.distance) {
        best = _HashMatchResult(item, distance);
      }
    }

    if (best == null) return null;

    final similarity = 1.0 - (best.distance / 64.0);
    if (similarity < _hashMatchThreshold && !allowLowConfidence) {
      debugPrint(
          '[NNES] Low hash similarity: ${similarity.toStringAsFixed(3)}');
      return null;
    }

    final profile = labDatabase[best.item.labId];
    if (profile == null) return null;

    final confidence = similarity < _hashMatchThreshold
        ? (0.55 + (similarity * 0.2)).clamp(0.55, 0.75)
        : (0.68 + (similarity - _hashMatchThreshold) * 0.3).clamp(0.68, 0.92);

    return LabDetectionResult(
      labId: profile.labId,
      labName: profile.labName,
      confidence: confidence,
      latitude: profile.latitude,
      longitude: profile.longitude,
      imageFile: imageFile,
      imageName: best.item.imageName,
      timestamp: DateTime.now(),
    );
  }

  static int? _computeAverageHash(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = img.copyResize(decoded,
        width: 8, height: 8, interpolation: img.Interpolation.linear);
    final pixels = <int>[];
    int sum = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final pixel = resized.getPixel(x, y);
        final gray =
            ((pixel.r * 0.299) + (pixel.g * 0.587) + (pixel.b * 0.114)).round();
        pixels.add(gray);
        sum += gray;
      }
    }

    final avg = sum / pixels.length;
    int hash = 0;
    for (int i = 0; i < pixels.length; i++) {
      if (pixels[i] >= avg) {
        hash |= (1 << i);
      }
    }

    return hash;
  }

  static int _hammingDistance(int a, int b) {
    int x = a ^ b;
    int count = 0;
    while (x != 0) {
      x &= (x - 1);
      count++;
    }
    return count;
  }

  static List<double> _extractEmbedding(Uint8List bytes) {
    if (_interpreter == null) return [];

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];

    final resized = img.copyResize(decoded,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear);

    final input = List.generate(
        1,
        (_) => List.generate(_inputSize,
            (y) => List.generate(_inputSize, (x) => List.filled(3, 0.0))));

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final outputSize = outputShape.reduce((a, b) => a * b) ~/ outputShape.first;
    final output = List.generate(1, (_) => List.filled(outputSize, 0.0));

    _interpreter!.run(input, output);
    return List<double>.from(output.first);
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  static String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isNotEmpty ? parts.last : path;
  }

  static String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static Future<LabDetectionResult?> _matchByOcr(File imageFile) async {
    if (_roomLabels.isEmpty) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFile(imageFile);
      final recognized = await recognizer.processImage(input);
      final text = recognized.text.trim();
      if (text.isEmpty) return null;

      final best = _bestFuzzyMatch(text);
      if (best == null || best.score < _ocrMatchThreshold) {
        return null;
      }

      final profile = labDatabase[best.labId];
      if (profile == null) return null;

      final confidence = (0.55 + best.score * 0.35).clamp(0.55, 0.9);
      return LabDetectionResult(
        labId: profile.labId,
        labName: profile.labName,
        confidence: confidence,
        latitude: profile.latitude,
        longitude: profile.longitude,
        imageFile: imageFile,
        imageName: _fileName(imageFile.path),
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }

  static void _buildRoomLabelIndex() {
    if (_roomLabels.isNotEmpty) return;
    for (final entry in labDatabase.entries) {
      final label = _normalizeText(entry.value.labName);
      _roomLabels.add(
        _NormalizedRoomLabel(
          labId: entry.key,
          label: label,
        ),
      );
    }
  }

  static _FuzzyMatchResult? _bestFuzzyMatch(String text) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) return null;

    _FuzzyMatchResult? best;
    for (final room in _roomLabels) {
      final score = _normalizedLevenshtein(normalized, room.label);
      if (best == null || score > best.score) {
        best = _FuzzyMatchResult(labId: room.labId, score: score);
      }
    }
    return best;
  }

  static double _normalizedLevenshtein(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final distance = _levenshteinDistance(a, b);
    final maxLen = max(a.length, b.length);
    return (1.0 - (distance / maxLen)).clamp(0.0, 1.0);
  }

  static int _levenshteinDistance(String a, String b) {
    final rows = a.length + 1;
    final cols = b.length + 1;
    final dp = List.generate(rows, (_) => List<int>.filled(cols, 0));

    for (int i = 0; i < rows; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j < cols; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i < rows; i++) {
      for (int j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    return dp[rows - 1][cols - 1];
  }

  static double _ratioScore(dynamic matches) {
    if (matches.length < 2) return 1.0;
    final distances = <double>[];
    for (final match in matches) {
      distances.add(match.distance);
    }
    distances.sort();
    final best = distances.first;
    final second = distances[1];
    if (second <= 0) return 0.0;
    return best / second;
  }

  static Uint8List _preprocessBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    var gray = img.grayscale(decoded);
    gray = _applyClahe(gray, clipLimit: 2.0, tileSize: 8);
    gray = img.gaussianBlur(gray, radius: 1);

    return Uint8List.fromList(img.encodeJpg(gray, quality: 90));
  }

  static img.Image _applyClahe(img.Image image,
      {double clipLimit = 2.0, int tileSize = 8}) {
    final width = image.width;
    final height = image.height;
    final result = image.clone();
    final clipLimitInt = max(1, (clipLimit * tileSize).round());

    for (int ty = 0; ty < height; ty += tileSize) {
      for (int tx = 0; tx < width; tx += tileSize) {
        final xEnd = min(tx + tileSize, width);
        final yEnd = min(ty + tileSize, height);
        final hist = List<int>.filled(256, 0);

        for (int y = ty; y < yEnd; y++) {
          for (int x = tx; x < xEnd; x++) {
            final pixel = image.getPixel(x, y);
            hist[pixel.r.toInt()] += 1;
          }
        }

        int excess = 0;
        for (int i = 0; i < hist.length; i++) {
          if (hist[i] > clipLimitInt) {
            excess += hist[i] - clipLimitInt;
            hist[i] = clipLimitInt;
          }
        }

        final redistribution = excess ~/ 256;
        for (int i = 0; i < hist.length; i++) {
          hist[i] += redistribution;
        }

        final cdf = List<int>.filled(256, 0);
        int cumulative = 0;
        for (int i = 0; i < hist.length; i++) {
          cumulative += hist[i];
          cdf[i] = cumulative;
        }

        final total = (xEnd - tx) * (yEnd - ty);
        for (int y = ty; y < yEnd; y++) {
          for (int x = tx; x < xEnd; x++) {
            final pixel = image.getPixel(x, y);
            final value = pixel.r.toInt();
            final equalized =
                ((cdf[value] - cdf[0]) * 255) ~/ max(1, total - 1);
            result.setPixelRgb(x, y, equalized, equalized, equalized);
          }
        }
      }
    }

    return result;
  }

  static String? _mapFileNameToLabId(String fileName) {
    final name = _normalizeText(fileName);

    if (name.contains('gnss')) return 'GNSS_Lab';
    if (name.contains('lidar')) return 'LiDAR_Lab';
    if (name.contains('computational')) return 'Computational_Lab';
    if (name.contains('gents washroom') || name.contains('ladies washroom')) {
      return 'Washrooms';
    }
    if (name.contains('washroom')) return 'Washrooms';
    if (name.contains('ceo')) return 'CEO_Room';
    if (name.contains('cafeteria') || name.contains('coffee')) {
      return 'Cafeteria';
    }
    if (name.contains('main meeting room') || name.contains('meeting room')) {
      return 'Meeting_Room';
    }
    if (name.contains('geo intel')) return 'GEO_Intel_Lab';
    if (name.contains('gis lab')) return 'GIS_Lab';
    if (name.contains('cv lab')) return 'CV_Lab';
    if (name.contains('pd room') || name.contains('pd')) return 'PD_Room';
    if (name.contains('discussion')) return 'Discussion_Area';
    if (name.contains('front desk') || name.contains('administrative')) {
      return 'Admin_Room';
    }
    if (name.contains('tih starting') ||
        name.contains('starting board') ||
        name.contains('starting door') ||
        name.contains('starting arch') ||
        name.contains('tih board')) {
      return 'TIH_Board';
    }

    if (name.contains('discussion place') || name.contains('discussion area')) {
      return 'Discussion_Area';
    }

    if (name.contains('infront of lidar')) return 'LiDAR_Lab';

    if (name.contains('main meeting')) return 'Meeting_Room';

    if (name.contains('geo intel lab')) return 'GEO_Intel_Lab';

    return null;
  }

  static LabDetectionResult? _fallbackByFileName(File imageFile) {
    final imageName = _fileName(imageFile.path);
    final labId = _mapFileNameToLabId(imageName);
    if (labId == null) return null;

    final profile = labDatabase[labId];
    if (profile == null) return null;

    return LabDetectionResult(
      labId: profile.labId,
      labName: profile.labName,
      confidence: 0.72,
      latitude: profile.latitude,
      longitude: profile.longitude,
      imageFile: imageFile,
      imageName: imageName,
      timestamp: DateTime.now(),
    );
  }
}

class _AssetEmbedding {
  final String labId;
  final String imageName;
  final List<double> embedding;

  _AssetEmbedding({
    required this.labId,
    required this.imageName,
    required this.embedding,
  });
}

class _MatchResult {
  final _AssetEmbedding item;
  final double similarity;

  _MatchResult(this.item, this.similarity);
}

class _AssetHash {
  final String labId;
  final String imageName;
  final int hash;

  _AssetHash({
    required this.labId,
    required this.imageName,
    required this.hash,
  });
}

class _HashMatchResult {
  final _AssetHash item;
  final int distance;

  _HashMatchResult(this.item, this.distance);
}

class _AssetDescriptor {
  final String labId;
  final String imageName;
  final cv.Mat descriptors;
  final int keypointCount;

  _AssetDescriptor({
    required this.labId,
    required this.imageName,
    required this.descriptors,
    required this.keypointCount,
  });
}

class _DescriptorResult {
  final cv.Mat descriptors;
  final int keypointCount;

  _DescriptorResult({
    required this.descriptors,
    required this.keypointCount,
  });
}

class _OrbMatchResult {
  final String labId;
  final String imageName;
  final double score;
  final int matchCount;

  _OrbMatchResult({
    required this.labId,
    required this.imageName,
    required this.score,
    required this.matchCount,
  });
}

class _FusionCandidate {
  _FusionCandidate({required this.detection})
      : bestDetection = detection,
        bestScore = 0.0;

  final LabDetectionResult detection;
  LabDetectionResult bestDetection;
  double scoreSum = 0.0;
  int count = 0;
  double bestScore;
}

class _NormalizedRoomLabel {
  final String labId;
  final String label;

  const _NormalizedRoomLabel({required this.labId, required this.label});
}

class _FuzzyMatchResult {
  final String labId;
  final double score;

  const _FuzzyMatchResult({required this.labId, required this.score});
}

class ImageMatchOutcome {
  final LabDetectionResult? detection;
  final String? hint;
  final double? confidenceScore;
  final String? locationName;

  const ImageMatchOutcome({
    this.detection,
    this.hint,
    this.confidenceScore,
    this.locationName,
  });
}

/// Lab image profile for database
class LabImageProfile {
  final String labId;
  final String labName;
  final List<String> keywords;
  final double confidence;
  final double latitude;
  final double longitude;

  LabImageProfile({
    required this.labId,
    required this.labName,
    required this.keywords,
    required this.confidence,
    required this.latitude,
    required this.longitude,
  });
}

/// Result of image recognition
class LabDetectionResult {
  final String labId;
  final String labName;
  final double confidence;
  final double latitude;
  final double longitude;
  final File imageFile;
  final String imageName;
  final DateTime timestamp;

  LabDetectionResult({
    required this.labId,
    required this.labName,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.imageFile,
    required this.imageName,
    required this.timestamp,
  });

  @override
  String toString() =>
      'Detected: $labName (Confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}
