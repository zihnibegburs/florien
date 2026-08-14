class TaskIconClassifierConfig {
  const TaskIconClassifierConfig({
    this.modelAsset = 'assets/task_icons/lealla_small_int8.onnx',
    this.vocabularyAsset = 'assets/task_icons/vocab.txt',
    this.prototypeAsset = 'assets/task_icons/category_embeddings.i8',
    this.prototypeManifestAsset =
        'assets/task_icons/category_embeddings_manifest.json',
    this.embeddingDimensions = 128,
    this.maxSequenceLength = 48,
    this.topExamplesPerCategory = 3,
    this.minimumConfidence = .47,
    this.minimumConfidenceMargin = .05,
    this.shortTextMinimumConfidence = .08,
    this.shortTextCodePointLimit = 48,
    this.switchMargin = .045,
    this.cacheCapacity = 128,
    this.debugCandidateCount = 5,
  });

  final String modelAsset;
  final String vocabularyAsset;
  final String prototypeAsset;
  final String prototypeManifestAsset;
  final int embeddingDimensions;
  final int maxSequenceLength;
  final int topExamplesPerCategory;
  final double minimumConfidence;
  final double minimumConfidenceMargin;

  /// Floor for everyday titles. Best-guess is enough; accuracy can be coarse.
  final double shortTextMinimumConfidence;
  final int shortTextCodePointLimit;
  final double switchMargin;
  final int cacheCapacity;
  final int debugCandidateCount;
}
